#!/usr/bin/env bash
# =============================================================================
# DOG-IA | Aula 07 - Parte 2 (Aplicação da Etapa 2: Workspace e código Python)
#
# Executa e registra o Passo 4 da Etapa 2 + os itens do checklist:
#   1. colcon build --symlink-install do pacote dog_ia_core em ~/ros2_ws
#   2. Confere se o executável 'valida_ambiente' foi registrado (setup.py)
#   3. Sobe o nó por alguns segundos e verifica:
#        - nó /valida_ambiente_node ativo
#        - tópico /dog_ia/status com tipo std_msgs/msg/String
#        - mensagem recebida com 'ros2 topic echo'
#        - frequência ~0,5 Hz (1 mensagem a cada 2 s) com 'ros2 topic hz'
#   4. (opcional) colcon test com os linters do ROS 2 (flake8 / pep257)
#
# A saída vai para a tela e para docs/evidencias/aula07/etapa2_<data>.log
#
# Uso:  bash scripts/valida_etapa2.sh             (build + execução)
#       bash scripts/valida_etapa2.sh --testes    (também roda colcon test)
#       WS=~/outro_ws bash scripts/valida_etapa2.sh
# =============================================================================

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${WS:-$HOME/ros2_ws}"
RODAR_TESTES=0
[ "${1:-}" = "--testes" ] && RODAR_TESTES=1
EVID_DIR="$REPO_DIR/docs/evidencias/aula07"
mkdir -p "$EVID_DIR"
LOG="$EVID_DIR/etapa2_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG") 2>&1

OK=0; FALHA=0; AVISO=0
ok()    { echo "  [OK]    $*"; OK=$((OK + 1)); }
falha() { echo "  [FALHA] $*"; FALHA=$((FALHA + 1)); }
aviso() { echo "  [AVISO] $*"; AVISO=$((AVISO + 1)); }
secao() { echo; echo "== $* =="; }

echo "============================================================"
echo " DOG-IA | Etapa 2 - Pacote dog_ia_core / nó valida_ambiente"
echo " Data: $(date '+%d/%m/%Y %H:%M:%S') | Máquina: $(hostname)"
echo " Workspace: $WS"
echo "============================================================"

# shellcheck disable=SC1091
[ -z "${ROS_DISTRO:-}" ] && [ -f /opt/ros/humble/setup.bash ] && . /opt/ros/humble/setup.bash
if [ "${ROS_DISTRO:-}" != "humble" ]; then
  echo "ROS 2 Humble não encontrado. Rode antes: bash scripts/check_env.sh"
  exit 1
fi

# -----------------------------------------------------------------------------
secao "0. Localização do pacote"
case "$REPO_DIR" in
  "$WS"/src/*) ok "repositório dentro de $WS/src" ;;
  *) falha "o repositório está em $REPO_DIR, fora de $WS/src - o colcon não vai achar o pacote"
     echo "        Corrija com:  mv \"$REPO_DIR\" \"$WS/src/\"   (ou clone de novo lá)"
     exit 1 ;;
esac
[ -f "$REPO_DIR/dog_ia_core/package.xml" ] && ok "dog_ia_core/package.xml encontrado" \
  || { falha "dog_ia_core/package.xml não encontrado"; exit 1; }

# -----------------------------------------------------------------------------
secao "1. Compilação (colcon build --symlink-install)"
cd "$WS" || exit 1
if colcon build --symlink-install --packages-select dog_ia_core; then
  ok "colcon build concluído"
else
  falha "colcon build falhou (veja o erro acima)"
  exit 1
fi
# shellcheck disable=SC1091
. "$WS/install/setup.bash"
grep -q "source $WS/install/setup.bash\|source ~/ros2_ws/install/setup.bash" "$HOME/.bashrc" 2>/dev/null \
  || aviso "~/.bashrc não carrega o overlay: echo \"source ~/ros2_ws/install/setup.bash\" >> ~/.bashrc"

# -----------------------------------------------------------------------------
secao "2. Executável registrado no setup.py"
EXECS="$(ros2 pkg executables dog_ia_core 2>/dev/null)"
echo "  $EXECS"
echo "$EXECS" | grep -q "valida_ambiente" && ok "executável 'valida_ambiente' registrado" \
  || falha "executável não encontrado - confira entry_points no setup.py"

# -----------------------------------------------------------------------------
secao "3. Execução do nó e inspeção do tópico"
NODE_LOG="$(mktemp)"
timeout -s INT 25 ros2 run dog_ia_core valida_ambiente >"$NODE_LOG" 2>&1 &
NODE_PID=$!
sleep 5

echo "  \$ ros2 node list"
ros2 node list 2>/dev/null | sed 's/^/    /'
ros2 node list 2>/dev/null | grep -q "/valida_ambiente_node" \
  && ok "nó /valida_ambiente_node ativo" || falha "nó /valida_ambiente_node não apareceu"

echo "  \$ ros2 topic list"
ros2 topic list 2>/dev/null | sed 's/^/    /'

echo "  \$ ros2 topic info /dog_ia/status"
INFO="$(ros2 topic info /dog_ia/status 2>/dev/null)"
echo "$INFO" | sed 's/^/    /'
echo "$INFO" | grep -q "std_msgs/msg/String" && ok "tópico /dog_ia/status do tipo std_msgs/msg/String" \
  || falha "tópico /dog_ia/status não encontrado"
N_PUB="$(echo "$INFO" | awk -F': ' '/Publisher count/ {print $2}')"
if [ "${N_PUB:-0}" -gt 1 ]; then
  aviso "$N_PUB publicadores em /dog_ia/status: outro grupo está na mesma rede/ROS_DOMAIN_ID"
fi

echo "  \$ ros2 topic echo /dog_ia/status --once"
ECHO="$(timeout 8 ros2 topic echo /dog_ia/status --once 2>/dev/null)"
echo "$ECHO" | sed 's/^/    /'
echo "$ECHO" | grep -q "DOG-IA Operacional" && ok "mensagem 'DOG-IA Operacional...' recebida" \
  || falha "nenhuma mensagem válida recebida em /dog_ia/status"

echo "  \$ ros2 topic hz /dog_ia/status   (~9 s)"
HZ="$(timeout -s INT 9 ros2 topic hz /dog_ia/status 2>/dev/null)"
echo "$HZ" | tail -4 | sed 's/^/    /'
RATE="$(echo "$HZ" | awk '/average rate/ {r=$3} END {print r}')"
if [ -n "$RATE" ] && awk -v r="$RATE" 'BEGIN {exit !(r > 0.4 && r < 0.6)}'; then
  ok "frequência média $RATE Hz (esperado 0,5 Hz = timer de 2,0 s)"
else
  aviso "frequência média '${RATE:-não medida}' Hz (esperado ~0,5 Hz)"
fi

echo "  \$ ros2 topic info /dog_ia/imagem_teste"
ros2 topic info /dog_ia/imagem_teste 2>/dev/null | sed 's/^/    /'

wait "$NODE_PID" 2>/dev/null
echo "  --- log do nó (ros2 run dog_ia_core valida_ambiente) ---"
sed 's/^/    /' "$NODE_LOG"
grep -q "pixels identicos" "$NODE_LOG" && ok "autoteste do cv_bridge aprovado" \
  || falha "autoteste do cv_bridge não aprovado (veja o log do nó)"
rm -f "$NODE_LOG"

# -----------------------------------------------------------------------------
if [ "$RODAR_TESTES" = "1" ]; then
  secao "4. Testes de estilo do ROS 2 (colcon test)"
  colcon test --packages-select dog_ia_core
  if colcon test-result --verbose; then
    ok "colcon test sem falhas"
  else
    falha "colcon test com falhas (veja acima)"
  fi
fi

# -----------------------------------------------------------------------------
echo
echo "============================================================"
echo " RESUMO: $OK OK | $AVISO aviso(s) | $FALHA falha(s)"
echo " Log salvo em: ${LOG#"$REPO_DIR"/}"
echo "============================================================"
[ "$FALHA" -eq 0 ]
