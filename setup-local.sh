#!/bin/bash
# Restores a known-good local dev environment for Aurora Corporate (MAMP).
# Safe to re-run after composer install or module updates.

set -e

DIR=$(cd "$(dirname "$0")" && pwd)
MAMP_URL="${AURORA_URL:-http://localhost:8888/}"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# CoreMobileWebclient is excluded: its vue-mobile/ subproject lives on local/quasar-v4-upgrade.
MOBILE_MODULES=(
  CoreParanoidEncryptionWebclientPlugin
  ContactsMobileWebclient
  FilesMobileWebclient
  MailMobileWebclient
  OpenPgpMobileWebclient
  OpenPgpFilesMobileWebclient
  SettingsMobileWebclient
  StandardLoginFormMobileWebclient
)

log() { printf "${GREEN}%s${NC}\n" "$1"; }
warn() { printf "${YELLOW}%s${NC}\n" "$1"; }

write_env_files() {
  log "Writing .env and mobile env.js for ${MAMP_URL}"
  cat > "${DIR}/.env" <<EOF
VUE_APP_API_HOST=${MAMP_URL}
EOF

  mkdir -p "${DIR}/modules/CoreMobileWebclient/vue-mobile"
  cat > "${DIR}/modules/CoreMobileWebclient/vue-mobile/env.js" <<EOF
module.exports = {
    API_ENDPOINT: '${MAMP_URL}'
}
EOF
}

write_adminpanel_index() {
  log "Writing adminpanel/index.php (reset aurora-mobile cookie for admin API)"
  mkdir -p "${DIR}/adminpanel"
  cat > "${DIR}/adminpanel/index.php" <<'EOF'
<?php
  include_once '../system/autoload.php';

  use Aurora\System\Api;
  use Aurora\System\Application;
  use Aurora\System\Managers\Integrator;

  // Override aurora-mobile=1 from mobile webclient (path /) so admin API uses desktop modules.
  @\setcookie(
    Integrator::MOBILE_KEY,
    '0',
    \strtotime('+200 days'),
    '/',
    null,
    false
  );

  if (is_array($_GET) && count($_GET) > 0) {
    Api::Init();
    Application::setBaseUrl(\substr(Application::getBaseUrl(), 0, -strlen(basename(__DIR__))-1));
    Application::Start();
  } else {
    include_once './main.html';
  }
EOF
}

fix_php_autoload() {
  log "Regenerating Composer autoload (fixes Doctrine Inflector / login errors)"
  cd "${DIR}"
  php composer.phar dump-autoload -o
}

clear_cache() {
  log "Clearing data/cache"
  rm -rf "${DIR}/data/cache"/*
}

ensure_mobile_webclient_branch() {
  path="${DIR}/modules/CoreMobileWebclient"
  if [ ! -d "${path}/.git" ]; then
    warn "CoreMobileWebclient is not a git repo, skipping branch checkout"
    return
  fi
  cd "${path}"
  if git show-ref --verify --quiet refs/heads/local/quasar-v4-upgrade; then
    if [ "$(git branch --show-current)" != "local/quasar-v4-upgrade" ]; then
      git checkout -f local/quasar-v4-upgrade
    fi
    log "CoreMobileWebclient -> local/quasar-v4-upgrade"
  else
    warn "CoreMobileWebclient: local/quasar-v4-upgrade branch not found"
  fi
}

ensure_admin_webclient_branch() {
  path="${DIR}/modules/AdminPanelWebclient"
  if [ ! -d "${path}/.git" ]; then
    warn "AdminPanelWebclient is not a git repo, skipping branch checkout"
    return
  fi
  cd "${path}"
  if git show-ref --verify --quiet refs/heads/local/quasar-v4-upgrade; then
    if [ "$(git branch --show-current)" != "local/quasar-v4-upgrade" ]; then
      git checkout -f local/quasar-v4-upgrade
    fi
    log "AdminPanelWebclient -> local/quasar-v4-upgrade"
  else
    warn "AdminPanelWebclient: local/quasar-v4-upgrade branch not found"
  fi
}

run_build_script() {
  dir="$1"
  cd "${dir}"
  if [ -f build-scripts/build-production.cjs ]; then
    node build-scripts/build-production.cjs
  elif [ -f build-scripts/build-production.js ]; then
    node build-scripts/build-production.js
  else
    printf "${RED}No build-production script in ${dir}${NC}\n" >&2
    exit 1
  fi
}

checkout_mobile_modules() {
  log "Checking out vue-mobile branch for mobile modules"
  for module in "${MOBILE_MODULES[@]}"; do
    path="${DIR}/modules/${module}"
    if [ ! -d "${path}/.git" ]; then
      warn "  skip ${module} (not a git repo)"
      continue
    fi
    cd "${path}"
    if git show-ref --verify --quiet refs/remotes/origin/vue-mobile; then
      git fetch origin 2>/dev/null || true
      git checkout -f vue-mobile 2>/dev/null || git checkout -b vue-mobile origin/vue-mobile
      git reset --hard origin/vue-mobile
      printf "  ${GREEN}%-40s${NC} vue-mobile\n" "${module}"
    else
      warn "  ${module}: no origin/vue-mobile branch"
    fi
  done
}

build_mobile() {
  log "Building mobile app (vue-mobile)"
  ensure_mobile_webclient_branch
  write_env_files
  cd "${DIR}/modules/CoreMobileWebclient/vue-mobile"
  if [ ! -d node_modules ]; then
    npm install --legacy-peer-deps
  fi
  run_build_script "${DIR}/modules/CoreMobileWebclient/vue-mobile"
}

build_admin() {
  log "Building admin panel"
  ensure_admin_webclient_branch
  cd "${DIR}/modules/AdminPanelWebclient/vue"
  if [ ! -d node_modules ]; then
    npm install --legacy-peer-deps
  fi
  run_build_script "${DIR}/modules/AdminPanelWebclient/vue"
  write_adminpanel_index
}

print_urls() {
  printf "\n${GREEN}Ready.${NC} Open:\n"
  printf "  Desktop:  %s\n" "${MAMP_URL}"
  printf "  Admin:    %sadminpanel/  (superadmin / empty password)\n" "${MAMP_URL}"
  printf "  Mobile:   %s?mobile-version\n" "${MAMP_URL}"
  printf "\n${YELLOW}Notes:${NC}\n"
  printf "  - MAMP Document Root should point to this folder.\n"
  printf "  - Do not use /aurora-corporate-8/ in URL if Document Root is already this project.\n"
  printf "  - Avoid 'composer install' unless needed; use ./update-mobile.sh for mobile updates.\n"
  printf "  - Chrome extension console errors (chrome-extension://) are not from Aurora.\n"
}

# --- main ---
write_env_files
write_adminpanel_index
fix_php_autoload
clear_cache

case "${1:-}" in
  --full)
    checkout_mobile_modules
    build_mobile
    build_admin
    ;;
  --mobile-modules)
    checkout_mobile_modules
    ensure_mobile_webclient_branch
    ensure_admin_webclient_branch
    write_env_files
    ;;
  --build)
    build_mobile
    build_admin
    ;;
  --help|-h)
    printf "Usage: %s [--full | --build | --mobile-modules]\n" "$0"
    printf "  (no args)  env files, admin index.php, autoload, clear cache\n"
    printf "  --full     also reset mobile modules and rebuild mobile + admin\n"
    printf "  --build    rebuild mobile + admin only\n"
    printf "  --mobile-modules  checkout vue-mobile branches only\n"
    printf "\nSet AURORA_URL to override base URL (default: http://localhost:8888/)\n"
    exit 0
    ;;
esac

print_urls
