#!/usr/bin/env bash
# =============================================================================
# DOG-IA | Aula 07 - Parte 1 (Revisão da Etapa 1: Configuração do Ambiente)
#
# Confere, em um único comando, tudo o que a Etapa 1 pediu:
#   1. Sistema operacional (Ubuntu 22.04, nativo ou WSL2)
#   2. ROS 2 Humble carregado no terminal
#   3. Pacotes de simulação, visão e teleoperação instalados
#   4. Gazebo e RViz2 disponíveis + aceleração gráfica (GPU / WSLg)
#   5. Teste 1 do guia: rclpy + OpenCV + cv_bridge no Python
#   6. Smoke test de comunicação: talker (C++) -> listener (Python)
#   7. Workspace ~/ros2_ws e localização do repositório
#
# A saída vai para a tela e para docs/evidencias/aula07/check_env_<data>.log
#
# Uso:  bash scripts/check_env.sh
#       WS=~/outro_ws bash scripts/check_env.sh   (workspace diferente)
# =============================================================================

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${WS:-$HOME/ros2_ws}"
EVID_DIR="$REPO_DIR/docs/evidencias/aula07"
mkdir -p "$EVID_DIR"
LOG="$EVID_DIR/check_env_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG") 2>&1

OK=0; FALHA=0; AVISO=0
ok()    { echo "  [OK]    $*"; OK=$((OK + 1)); }
falha() { echo "  [FALHA] $*"; FALHA=$((FALHA + 1)); }
aviso() { echo "  [AVISO] $*"; AVISO=$((AVISO + 1)); }
secao() { echo; echo "== $* =="; }

echo "============================================================"
echo " DOG-IA | Revisão da Etapa 1 - Validação do ambiente"
echo " Data:    $(date '+%d/%m/%Y %H:%M:%S')"
echo " Máquina: $(hostname) | Usuário: $(whoami)"
echo " Repo:    $REPO_DIR"
echo "============================================================"

# -----------------------------------------------------------------------------
secao "1. Sistema operacional"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  echo "  Distro: ${PRETTY_NAME:-desconhecida}"
  if [ "${VERSION_ID:-}" = "22.04" ]; then
    ok "Ubuntu 22.04 LTS (exigido pelo ROS 2 Humble)"
  else
    falha "Versão ${VERSION_ID:-?} - o guia exige Ubuntu 22.04 para o ROS 2 Humble"
  fi
fi
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "  Ambiente: WSL2 ($(uname -r))"
  IS_WSL=1
else
  echo "  Ambiente: Linux nativo ($(uname -r))"
  IS_WSL=0
fi

# -----------------------------------------------------------------------------
secao "2. ROS 2"
if [ -z "${ROS_DISTRO:-}" ] && [ -f /opt/ros/humble/setup.bash ]; then
  aviso "ROS 2 não estava carregado no terminal; carregando /opt/ros/humble/setup.bash"
  aviso "  -> confira se a linha 'source /opt/ros/humble/setup.bash' está no ~/.bashrc"
  # shellcheck disable=SC1091
  . /opt/ros/humble/setup.bash
fi
if [ "${ROS_DISTRO:-}" = "humble" ]; then
  ok "ROS_DISTRO=humble"
else
  falha "ROS_DISTRO='${ROS_DISTRO:-vazio}' (esperado: humble). Instale o ros-humble-desktop-full"
fi
if command -v ros2 >/dev/null 2>&1; then
  ok "comando ros2 encontrado em $(command -v ros2)"
else
  falha "comando ros2 não encontrado"
fi
grep -q "source /opt/ros/humble/setup.bash" "$HOME/.bashrc" 2>/dev/null \
  && ok "~/.bashrc carrega o ROS 2 automaticamente" \
  || aviso "~/.bashrc não tem 'source /opt/ros/humble/setup.bash' (Passo 3 da Etapa 1)"
echo "  ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-<não definido = 0>}"
echo "  ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-<não definido = 0>}"
echo "  RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-<padrão: rmw_fastrtps_cpp>}"
if [ -z "${ROS_DOMAIN_ID:-}" ]; then
  aviso "ROS_DOMAIN_ID não definido: no laboratório, os nós de outros grupos na mesma rede"
  aviso "  aparecem para vocês (e vice-versa). Sugestão: export ROS_DOMAIN_ID=<nº do grupo>"
fi

# -----------------------------------------------------------------------------
secao "3. Pacotes ROS 2 exigidos pelo guia"
for pkg in gazebo_ros xacro joint_state_publisher_gui teleop_twist_keyboard \
           cv_bridge demo_nodes_cpp demo_nodes_py rviz2; do
  if ros2 pkg prefix "$pkg" >/dev/null 2>&1; then
    ok "$pkg"
  else
    falha "$pkg não encontrado (sudo apt install ros-humble-${pkg//_/-})"
  fi
done
# Pacotes que serão usados nas próximas etapas (Nav2 / SLAM): só avisa.
for pkg in nav2_bringup slam_toolbox; do
  ros2 pkg prefix "$pkg" >/dev/null 2>&1 \
    && ok "$pkg (próximas etapas)" \
    || aviso "$pkg ausente - necessário a partir da etapa de 09/11 (ros-humble-${pkg//_/-})"
done

# -----------------------------------------------------------------------------
secao "4. Gazebo, RViz2 e aceleração gráfica"
if command -v gazebo >/dev/null 2>&1; then
  GZ_VER="$(timeout 15 gazebo --version 2>/dev/null | grep -io 'version [0-9.]*' | head -1)"
  ok "gazebo encontrado (${GZ_VER:-versão não lida})"
else
  falha "gazebo não encontrado (sudo apt install gazebo ros-humble-gazebo-ros-pkgs)"
fi
command -v rviz2 >/dev/null 2>&1 && ok "rviz2 encontrado" || falha "rviz2 não encontrado"
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  ok "sessão gráfica disponível (DISPLAY=${DISPLAY:-} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-})"
else
  falha "nenhuma sessão gráfica (DISPLAY/WAYLAND_DISPLAY vazios) - Gazebo e RViz2 não abrirão"
fi
if [ "$IS_WSL" = "1" ]; then
  [ -e /dev/dxg ] && ok "/dev/dxg presente (GPU do Windows exposta ao WSL2)" \
                  || aviso "/dev/dxg ausente - rode 'wsl --update' no PowerShell e reinicie o WSL"
fi
if command -v glxinfo >/dev/null 2>&1; then
  RENDER="$(glxinfo -B 2>/dev/null | grep -i 'OpenGL renderer' | cut -d: -f2- | sed 's/^ *//')"
  if [ -z "$RENDER" ]; then
    aviso "glxinfo não conseguiu abrir o display"
  elif echo "$RENDER" | grep -qi llvmpipe; then
    aviso "renderização por SOFTWARE ($RENDER) - Gazebo vai ficar lento; verifique driver/WSLg"
  else
    ok "renderização por GPU: $RENDER"
  fi
else
  aviso "glxinfo ausente (sudo apt install mesa-utils) - não deu para checar a GPU"
fi

# -----------------------------------------------------------------------------
secao "5. Teste 1 do guia - ambiente Python"
if python3 - <<'PY'
import rclpy
import cv2
from cv_bridge import CvBridge
import numpy as np

CvBridge()
print('  ==================================================')
print('  [1/3] ROS 2 Humble (rclpy): OK')
print(f'  [2/3] Visão Computacional (OpenCV {cv2.__version__}): OK')
print('  [3/3] Ponte ROS-OpenCV (cv_bridge): OK')
print(f'  NumPy {np.__version__}')
print('  ==================================================')
print('  AMBIENTE PYTHON PRONTO PARA O PROJETO DOG-IA!')
print('  ==================================================')
PY
then
  ok "rclpy, cv2 e cv_bridge importados sem erro"
else
  falha "erro de importação no Python (veja a mensagem acima)"
fi

# -----------------------------------------------------------------------------
secao "6. Smoke test de comunicação (talker C++ -> listener Python)"
TMP_TALKER="$(mktemp)"
TMP_LISTENER="$(mktemp)"
timeout -s INT 14 ros2 run demo_nodes_cpp talker >"$TMP_TALKER" 2>&1 &
TALKER_PID=$!
sleep 2
timeout -s INT 10 ros2 run demo_nodes_py listener >"$TMP_LISTENER" 2>&1
wait "$TALKER_PID" 2>/dev/null
echo "  --- talker (últimas linhas) ---"
grep "Publishing" "$TMP_TALKER" | tail -3 | sed 's/^/  /'
echo "  --- listener (últimas linhas) ---"
grep "I heard" "$TMP_LISTENER" | tail -3 | sed 's/^/  /'
N_HEARD="$(grep -c "I heard" "$TMP_LISTENER")"
if [ "$N_HEARD" -gt 0 ]; then
  ok "listener recebeu $N_HEARD mensagens do talker"
else
  falha "listener não recebeu nada (firewall, ROS_DOMAIN_ID diferente ou ROS não carregado)"
fi
rm -f "$TMP_TALKER" "$TMP_LISTENER"

# -----------------------------------------------------------------------------
secao "7. Workspace e repositório"
if [ -d "$WS/src" ]; then
  ok "workspace encontrado: $WS"
else
  falha "workspace $WS/src não existe (mkdir -p ~/ros2_ws/src)"
fi
case "$REPO_DIR" in
  "$WS"/src/*) ok "repositório está dentro de $WS/src (o colcon encontra os pacotes)" ;;
  *) aviso "repositório fora de $WS/src - clone em $WS/src/DOG-IA_ROBO_CAO-GUIA" ;;
esac
if git -C "$REPO_DIR" rev-parse >/dev/null 2>&1; then
  ok "repositório git: $(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo 'sem remote')"
fi

# -----------------------------------------------------------------------------
echo
echo "============================================================"
echo " RESUMO: $OK OK | $AVISO aviso(s) | $FALHA falha(s)"
echo " Log salvo em: ${LOG#"$REPO_DIR"/}"
echo " Testes gráficos (manuais): rode 'gazebo' e 'rviz2' em terminais"
echo " separados e tire print das duas janelas abertas."
echo "============================================================"
[ "$FALHA" -eq 0 ]
