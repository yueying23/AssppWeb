import AdmZip from "adm-zip"; // 1. 引入 adm-zip
import bplistCreator from "bplist-creator";
import bplistParser from "bplist-parser";
import { execFile as execFileCb } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import plist from "plist";
import type { Readable } from "stream";
import { promisify } from "util";
import { open as openZip } from "yauzl-promise";
import type { Sinf } from "../types/index.js";

const execFile = promisify(execFileCb);

interface IpaMetadata {
  bundleName: string;
  manifest: { sinfPaths: string[] } | null;
  info: { bundleExecutable: string } | null;
}

export async function inject(
  sinfs: Sinf[],
  ipaPath: string,
  iTunesMetadata?: string,
): Promise<void> {
  const { bundleName, manifest, info } = await readIpaMetadata(ipaPath);

  // Collect all files to inject
  const filesToInject: { entryPath: string; data: Buffer }[] = [];

  if (manifest) {
    for (let i = 0; i < manifest.sinfPaths.length; i++) {
      if (i >= sinfs.length) continue;
      const sinfPath = manifest.sinfPaths[i];
      const fullPath = `Payload/${bundleName}.app/${sinfPath}`;
      filesToInject.push({
        entryPath: fullPath,
        data: Buffer.from(sinfs[i].sinf, "base64"),
      });
    }
  } else if (info) {
    if (sinfs.length > 0) {
      const sinfPath = `Payload/${bundleName}.app/SC_Info/${info.bundleExecutable}.sinf`;
      filesToInject.push({
        entryPath: sinfPath,
        data: Buffer.from(sinfs[0].sinf, "base64"),
      });
    }
  } else {
    throw new Error("Could not read manifest or info plist");
  }

  // Inject iTunesMetadata.plist at the archive root if provided
  if (iTunesMetadata) {
    const xmlBuffer = Buffer.from(iTunesMetadata, "base64");
    const xmlString = xmlBuffer.toString("utf-8");
    let metadataBuffer: Buffer;
    try {
      const parsed = plist.parse(xmlString);
      metadataBuffer = bplistCreator(parsed as Record<string, unknown>);
    } catch {
      metadataBuffer = xmlBuffer;
    }
    filesToInject.push({
      entryPath: "iTunesMetadata.plist",
      data: metadataBuffer,
    });
  }

  if (filesToInject.length > 0) {
    await addFilesToZip(ipaPath, filesToInject);
  }
}

async function streamToBuffer(stream: Readable): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of stream) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks);
}

async function readIpaMetadata(ipaPath: string): Promise<IpaMetadata> {
  const zip = await openZip(ipaPath);
  try {
    let bundleName: string | null = null;
    let manifestData: Buffer | null = null;
    let infoPlistData: Buffer | null = null;

    for await (const entry of zip) {
      const filename = entry.filename;

      if (
        !bundleName &&
        filename.includes(".app/Info.plist") &&
        !filename.includes("/Watch/")
      ) {
        const components = filename.split("/");
        for (const component of components) {
          if (component.endsWith(".app")) {
            bundleName = component.slice(0, -4);
            break;
          }
        }
      }

      if (!manifestData && filename.endsWith(".app/SC_Info/Manifest.plist")) {
        const stream = await entry.openReadStream();
        manifestData = await streamToBuffer(stream);
      }

      if (
        !infoPlistData &&
        filename.includes(".app/Info.plist") &&
        !filename.includes("/Watch/")
      ) {
        const stream = await entry.openReadStream();
        infoPlistData = await streamToBuffer(stream);
      }
    }

    if (!bundleName) {
      throw new Error("Could not read bundle name");
    }

    let manifest: { sinfPaths: string[] } | null = null;
    if (manifestData) {
      const parsed = parsePlistBuffer(manifestData);
      if (parsed) {
        const sinfPaths = parsed["SinfPaths"];
        if (Array.isArray(sinfPaths)) {
          manifest = { sinfPaths: sinfPaths as string[] };
        }
      }
    }

    let info: { bundleExecutable: string } | null = null;
    if (infoPlistData) {
      const parsed = parsePlistBuffer(infoPlistData);
      if (parsed) {
        const executable = parsed["CFBundleExecutable"];
        if (typeof executable === "string") {
          info = { bundleExecutable: executable };
        }
      }
    }

    return { bundleName, manifest, info };
  } finally {
    await zip.close();
  }
}

/**
 * 智能添加文件到 ZIP
 * 策略：
 * 1. Windows: 直接使用 adm-zip (因为通常没有 zip 命令)
 * 2. Linux/Mac: 尝试使用系统 zip 命令 (高性能)，如果失败则 fallback 到 adm-zip
 */
async function addFilesToZip(
  ipaPath: string,
  files: { entryPath: string; data: Buffer }[],
): Promise<void> {
  const isWindows = process.platform === "win32";

  if (isWindows) {
    return await useAdmZip(ipaPath, files);
  }

  // Linux/Mac 尝试使用系统 zip
  try {
    // 快速检查 zip 是否可用
    await execFile("zip", ["-v"], { timeout: 2000 });
    return await useSystemZip(ipaPath, files);
  } catch (error) {
    console.warn("⚠️ System 'zip' command not found. Falling back to adm-zip.");
    return await useAdmZip(ipaPath, files);
  }
}

/**
 * 方案 A: 使用系统 zip 命令 (Linux/Mac 高性能)
 */
async function useSystemZip(
  ipaPath: string,
  files: { entryPath: string; data: Buffer }[],
): Promise<void> {
  const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "sinf-"));
  const resolvedTmpDir = path.resolve(tmpDir);
  try {
    const relativePaths: string[] = [];
    for (const file of files) {
      const fullPath = path.resolve(tmpDir, file.entryPath);
      if (!fullPath.startsWith(resolvedTmpDir + path.sep)) {
        throw new Error(`Path traversal detected in entry: ${file.entryPath}`);
      }
      await fs.promises.mkdir(path.dirname(fullPath), { recursive: true });
      await fs.promises.writeFile(fullPath, file.data);
      relativePaths.push(file.entryPath);
    }

    await execFile("zip", ["-0", ipaPath, "--", ...relativePaths], {
      cwd: tmpDir,
      maxBuffer: 1024 * 1024 * 10,
    });
  } finally {
    await fs.promises.rm(tmpDir, { recursive: true, force: true });
  }
}

/**
 * 方案 B: 使用 adm-zip (Windows 或无 zip 环境)
 */
async function useAdmZip(
  ipaPath: string,
  files: { entryPath: string; data: Buffer }[],
): Promise<void> {
  const zip = new AdmZip(ipaPath);
  
  for (const file of files) {
    // 简单的路径规范化，防止 ../ 遍历
    const safePath = path.normalize(file.entryPath).replace(/^(\.\.(\/|\\|$))+/, '');
    if (!safePath || safePath.startsWith('..')) {
        throw new Error(`Invalid path: ${file.entryPath}`);
    }
    zip.addFile(safePath, file.data);
  }
  
  zip.writeZip(ipaPath);
}

function parsePlistBuffer(data: Buffer): Record<string, unknown> | null {
  // Try binary plist first
  try {
    const parsed = bplistParser.parseBuffer(data);
    if (parsed && parsed.length > 0) {
      return parsed[0] as Record<string, unknown>;
    }
  } catch {
    // Not binary plist, try XML
  }

  // Try XML plist
  try {
    const xml = data.toString("utf-8");
    if (xml.includes("<?xml") || xml.includes("<plist")) {
      const parsed = plist.parse(xml);
      if (parsed && typeof parsed === "object") {
        return parsed as Record<string, unknown>;
      }
    }
  } catch {
    // Not valid XML plist either
  }

  return null;
}