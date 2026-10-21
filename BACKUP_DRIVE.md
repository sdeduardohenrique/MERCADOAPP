# Backup do SomaAí no Google Drive

## Resposta curta

**Sim, vale a pena — mas não sincronizando a pasta inteira.** O projeto tem ~9,7 GB, sendo quase tudo cache/build/SDK/venv. O Google Drive deve guardar uma **cópia limpa dos arquivos importantes**, não o projeto bruto com `build/`, `.dart_tool/`, `.venv/` e `HABILIDADES/tools/`.

A estratégia recomendada é:

| Camada | O que guarda | Para quê |
|---|---|---|
| **GitHub** | Código, histórico, docs, skills, patches | Fonte da verdade e histórico de versões |
| **Google Drive** | Snapshot do código + `.git` + APK + arquivos locais não versionados | Recuperação rápida se o GitHub ou a máquina falharem |
| **Gerenciador de senhas/cofre** | `.env`, keystore, tokens, senhas | Segredos não vão para o Drive sem criptografia |

O GitHub já é um backup do código. O Drive cobre o que o Git não cobre: APK, `.git` local, configurações da máquina e arquivos que você não quer versionar.

## Estado nesta máquina

O **rclone v1.75.2** já foi instalado em `~/.local/bin/rclone`. O que falta é apenas autorizar sua conta Google:

```bash
rclone config
```

Depois de criar o remote `gdrive`, o script `tools/backup_to_drive.sh` já está pronto para uso.

## Por que não sincronizar a pasta inteira

Não sincronize:

- `build/` — 4,3 GB de artefatos gerados;
- `.dart_tool/` — 457 MB de cache;
- `.venv/` — 604 MB de ambiente Python;
- `HABILIDADES/tools/` — 1,9 GB de repositórios de terceiros;
- `~/` — 2,5 GB de Android SDK local;
- `android/.gradle/` — 28 MB de cache;
- `.env`, keystores e `key.properties` — segredos.

Além do tamanho, sincronizar caches gera conflitos, arquivos temporários e backups inúteis.

## Instalar o rclone

No Ubuntu, o Google Drive não tem cliente oficial de desktop para Linux. O caminho mais confiável para backup automatizado é o **rclone**.

**Nesta máquina ele já está instalado** em `~/.local/bin/rclone` (v1.75.2). Confirme com:

```bash
command -v rclone
rclone version
```

Se `~/.local/bin` não estiver no `PATH`, adicione ao `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Para outra máquina, instale via apt:

```bash
sudo apt update
sudo apt install -y rclone rsync
rclone version
```

Se a versão do apt estiver antiga:

```bash
curl https://rclone.org/install.sh | sudo bash
```

## Configurar o Google Drive

```bash
rclone config
```

Passo a passo típico:

1. `n` — novo remote.
2. Nome: `gdrive`.
3. Storage: `drive`.
4. `client_id`: deixe em branco.
5. `client_secret`: deixe em branco.
6. Scope: `drive` (acesso completo ao Drive) ou `drive.file` (somente arquivos criados pelo rclone).
7. `root_folder_id`: deixe em branco.
8. `service_account_file`: deixe em branco.
9. Advanced config: `n`.
10. Use auto config: `y` — abre o navegador para autorizar sua conta Google.
11. Confirme e saia.

Teste:

```bash
rclone lsd gdrive:
rclone about gdrive:
```

Se a máquina não tiver navegador, rode `rclone authorize "drive"` em outra máquina com navegador e cole o token no configurador.

## Rodar o backup

Na raiz do projeto:

```bash
# 1. Teste local: só monta a cópia limpa, sem enviar ao Drive
bash tools/backup_to_drive.sh --local-only

# 2. Teste do envio, sem alterar o Drive
bash tools/backup_to_drive.sh --dry-run

# 3. Backup real
bash tools/backup_to_drive.sh
```

O script:

- monta uma cópia em `~/Backups/MERCADOAPP`;
- inclui código, testes, docs, skills, `.git` e o APK release;
- exclui caches, venv, SDK, ferramentas de 1,9 GB, `.env` e keystores;
- envia para `gdrive:MERCADOAPP-Backup/current`;
- guarda versões alteradas/removidas em `gdrive:MERCADOAPP-Backup/history/AAA-MM-DD_HHMMSS`;
- roda `rclone check` depois do envio.

Para usar outro remote ou pasta:

```bash
RCLONE_REMOTE="meudrive:SomaAi" bash tools/backup_to_drive.sh
```

Para mudar o staging local:

```bash
STAGING_DIR="$HOME/Backups/SomaAi" bash tools/backup_to_drive.sh
```

## Restaurar em outra máquina

```bash
mkdir -p "$HOME/Restore/MERCADOAPP"
rclone copy gdrive:MERCADOAPP-Backup/current "$HOME/Restore/MERCADOAPP" -P
cd "$HOME/Restore/MERCADOAPP"
```

Depois siga o `PROMPT_NOVA_MAQUINA.md`:

```bash
flutter pub get
bash tools/apply_mlkit_patches.sh
flutter test
```

Se o `.git` foi restaurado, o repositório já terá o remote configurado:

```bash
git status
git remote -v
```

## Agendar backup diário

Cron simples:

```bash
crontab -e
```

Adicione uma linha como:

```cron
0 22 * * * cd /home/supervisoreduardoalves/Público/MERCADOAPP && /usr/bin/bash tools/backup_to_drive.sh >> /home/supervisoreduardoalves/.local/state/somaai-backup.log 2>&1
```

Crie o diretório de log antes:

```bash
mkdir -p "$HOME/.local/state"
```

O backup é incremental: o rclone só envia o que mudou. O staging local também é atualizado com `rsync --delete`.

## Segredos

O script **exclui** `.env`, `*.jks`, `*.keystore` e `key.properties`. Isso é intencional.

Se precisar guardar esses arquivos no Drive:

1. Crie um arquivo criptografado com `age` ou `gpg`.
2. Guarde a senha/chave no gerenciador de senhas.
3. Envie apenas o arquivo criptografado para o Drive.

Exemplo com `age`:

```bash
age -p -o .env.age .env
# guarde .env.age no Drive; a senha fica no gerenciador de senhas
```

Nunca envie `.env` com `SUPABASE_SERVICE_ROLE_KEY` para o Drive sem criptografia.

## Verificação periódica

Uma vez por mês, teste uma restauração:

```bash
rclone copy gdrive:MERCADOAPP-Backup/current /tmp/somaai-restore -P
cd /tmp/somaai-restore
flutter pub get
bash tools/apply_mlkit_patches.sh
flutter test
```

Backup que nunca foi restaurado não é backup; é esperança.

## Alternativa com interface gráfica

Se você preferir uma interface gráfica em vez do rclone, o **InSync** é uma opção paga para Google Drive no Linux. Para automação e controle fino de exclusões, o rclone continua sendo a melhor escolha.
