import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { existsSync } from "node:fs";

const DATA_DIR = join(dirname(new URL(import.meta.url).pathname), "../../data");

export function projectDir(projectId: string): string {
  return join(DATA_DIR, "projects", projectId);
}

export async function ensureDir(dir: string): Promise<void> {
  if (!existsSync(dir)) {
    await mkdir(dir, { recursive: true });
  }
}

export async function readJson<T>(filePath: string): Promise<T | null> {
  try {
    const data = await readFile(filePath, "utf-8");
    return JSON.parse(data) as T;
  } catch {
    return null;
  }
}

export async function writeJson(filePath: string, data: unknown): Promise<void> {
  await ensureDir(dirname(filePath));
  await writeFile(filePath, JSON.stringify(data, null, 2), "utf-8");
}

export async function readText(filePath: string): Promise<string | null> {
  try {
    return await readFile(filePath, "utf-8");
  } catch {
    return null;
  }
}

export async function writeText(filePath: string, content: string): Promise<void> {
  await ensureDir(dirname(filePath));
  await writeFile(filePath, content, "utf-8");
}

export async function listFiles(dir: string): Promise<string[]> {
  try {
    return await readdir(dir);
  } catch {
    return [];
  }
}
