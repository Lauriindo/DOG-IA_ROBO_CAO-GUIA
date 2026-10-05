# DOG-IA — Robô Cão-Guia Urbano de Inteligência Assistiva

Protótipo de um robô guia autônomo, em ambiente simulado (ROS 2 + Gazebo + RViz2), para auxiliar a mobilidade urbana de pessoas com deficiência visual.

Projeto das avaliações **AC-3 (Fase 1)** e **AC-4 (Fase 2)** da disciplina **Intelligent Mobile Robots (IMR)** — Ciência da Computação, 2º semestre de 2026. Professor: Flavio Santarelli.

## Integrantes

| Nome completo | R.A. |
|---|---|
| Leandro Laurindo Soares | 82263 |
| Camila Cesco Ferreira | 134666 |
| Marcelo Luna Ierardi | 95121 |

## Documentação

| Documento | Descrição |
|---|---|
| [`docs/escopo_dog-ia_robo.md`](docs/escopo_dog-ia_robo.md) | Escopo, requisitos, arquitetura preliminar, cronograma e riscos |
| [`docs/validacao_ambiente.md`](docs/validacao_ambiente.md) | Registro da validação do ambiente (Etapa 1 — 05/10) |
| [`docs/evidencias/`](docs/evidencias/) | Prints e saídas de terminal das validações |

## Estrutura do repositório

```
DOG-IA_ROBO_CAO-GUIA/
├── README.md
├── .gitignore
├── docs/
│   ├── escopo_dog-ia_robo.md
│   ├── validacao_ambiente.md
│   └── evidencias/
├── scripts/
│   ├── check_env.sh          # valida SO, WSLg/GPU, ROS 2, Gazebo, RViz2 e pacotes
│   └── validate_python.py    # Teste 1 do guia oficial (rclpy, OpenCV, cv_bridge)
└── ros2_ws/
    └── src/                  # pacotes ROS 2 (Python) do projeto
```

## Como começar

```bash
git clone https://github.com/<usuario>/DOG-IA_ROBO_CAO-GUIA.git
cd DOG-IA_ROBO_CAO-GUIA

# valida o ambiente e grava a saída em docs/evidencias/
bash scripts/check_env.sh
python3 scripts/validate_python.py

# compila o workspace (quando houver pacotes em ros2_ws/src)
cd ros2_ws
colcon build --symlink-install
source install/setup.bash
```

## Cronograma resumido

| Data | Entrega | Pontos |
|---|---|---|
| 05/10 | Setup de ambiente (WSL2/Linux, ROS 2, Gazebo, RViz2, Docker) | 0,25 |
| 26/10 | Modelagem URDF/Xacro do robô e sensores 3D | 0,25 |
| 09/11 | Mapeamento SLAM 2D e navegação com Nav2 | 0,50 |
| 16/11 | Visão computacional (semáforos / faixas) | 0,25 |
| 23/11 | Áudio (HRI), testes de campo, vídeo e relatório | 0,25 |
| 30/11 | Apresentação final | 0,50 |
