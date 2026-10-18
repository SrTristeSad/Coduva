#!/usr/bin/env python3
"""Prepara metadados de release para PHP/MariaDB a partir de ZIP já compilado.

Uso:
 python tools/gerar_catalogo_release.py --id php --abi arm64-v8a \
   --version 8.x.y --tag php-android-v8.x.y --zip ./php-android-arm64-v8a.zip

ATENÇÃO: isto não compila PHP nem MariaDB para Android; o ZIP deve ter sido
construído, auditado e testado previamente. GitHub Release deve ser publicado
ANTES de commitar o catálogo atualizado.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

OWNER_REPO = "SrTristeSad/Coduva"
IDS = {"php", "mariadb"}
ABIS = {"arm64-v8a", "armeabi-v7a", "x86_64"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True, choices=sorted(IDS))
    parser.add_argument("--abi", required=True, choices=sorted(ABIS))
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--zip", required=True, type=Path)
    parser.add_argument("--catalog", type=Path, default=Path("assets/runtime_catalog.json"))
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._+-]{0,79}", args.version):
        parser.error("Versão inválida.")
    if not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._-]{0,79}", args.tag):
        parser.error("Tag inválida.")
    if not args.zip.is_file():
        parser.error("ZIP não encontrado.")
    if not args.zip.name.endswith(".zip"):
        parser.error("O pacote precisa ser ZIP.")

    with zipfile.ZipFile(args.zip) as archive:
        bad = archive.testzip()
        if bad is not None:
            parser.error(f"Arquivo ZIP corrompido: {bad}")
        for item in archive.infolist():
            name = item.filename.replace("\\", "/")
            if (
                name.startswith("/")
                or ".." in name.split("/")
                or not name
                or name.startswith("./")
            ):
                parser.error(f"Caminho proibido dentro do ZIP: {name}")
        if not archive.namelist():
            parser.error("ZIP vazio.")

    digest = hashlib.sha256()
    with args.zip.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    if catalog.get("schema") != 1:
        parser.error("Schema do catálogo incompatível.")
    candidates = [p for p in catalog["packages"]
                  if p["id"] == args.id and p["abi"] == args.abi]
    if len(candidates) != 1:
        parser.error("Não existe exatamente um pacote com ID/ABI solicitado.")
    entry = candidates[0]
    entry["version"] = args.version
    entry["releaseUrl"] = (
        f"https://github.com/{OWNER_REPO}/releases/download/{args.tag}/{args.zip.name}"
    )
    entry["sha256"] = digest.hexdigest()
    entry["state"] = "published"
    args.catalog.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("Catálogo atualizado localmente:", args.catalog)
    print("SHA-256:", digest.hexdigest())
    print("Publique primeiro o ZIP no GitHub Release com tag:", args.tag)
    print("Só depois faça commit/push do catálogo para evitar download 404.")
    print("AVISO: pacote válido não significa execução nativa habilitada no Android.")

if __name__ == "__main__":
    main()
