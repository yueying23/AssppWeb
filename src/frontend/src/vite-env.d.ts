/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ACCOUNT_HASH_SALT?: string;
  // 其他环境变量可以在这里定义
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
