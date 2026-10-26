#!/usr/bin/env python3
# Define o interpretador Python 3 para a execução do script.
"""
Nó de validação do ambiente do DOG-IA (Aula 07, Etapa 2).

O nó faz duas coisas:
1. Na inicialização, executa um autoteste da ponte ROS 2 <-> OpenCV
   (cv_bridge): cria uma imagem sintética no OpenCV, converte para
   sensor_msgs/Image e converte de volta, conferindo se os pixels batem.
2. A cada `periodo_s` segundos (padrão 2.0 s), publica o status do sistema
   no tópico /dog_ia/status (std_msgs/String) e a imagem sintética no tópico
   /dog_ia/imagem_teste (sensor_msgs/Image), que pode ser vista no RViz2.
"""

import cv2
# Importa a biblioteca OpenCV para processamento de imagens e visão.

from cv_bridge import CvBridge
# Importa o conversor de mensagens de imagem do ROS para OpenCV (e vice-versa).

import numpy as np
# Importa o NumPy: no OpenCV, uma imagem é um numpy.ndarray (altura x largura x canais).

import rclpy
# Importa a biblioteca oficial do ROS 2 para Python (rclpy).

from rclpy.node import Node
# Importa a classe base 'Node' necessária para criar nós do ROS 2.

from sensor_msgs.msg import Image
# Importa o tipo de mensagem de imagem padrão do ROS 2 (sensor_msgs/Image).

from std_msgs.msg import String
# Importa o tipo de mensagem textual padrão (std_msgs/String).

MSG_OK = 'DOG-IA Operacional: ROS 2 + OpenCV Prontos!'
# Texto publicado quando o autoteste passa (o mesmo texto do guia da aula).

MSG_FALHA = 'DOG-IA com FALHA: ponte ROS 2 <-> OpenCV (cv_bridge) nao validou!'
# Texto publicado se o autoteste do cv_bridge falhar.


class ValidaAmbienteNode(Node):
    """Nó de validação do ambiente; herda da classe 'Node' do ROS 2."""

    def __init__(self):
        super().__init__('valida_ambiente_node')
        # Inicializa o nó com o nome registrado 'valida_ambiente_node'.

        self.declare_parameter('periodo_s', 2.0)
        # Declara o parâmetro 'periodo_s' (padrão 2.0 s, igual ao guia).
        # Pode ser alterado sem recompilar: --ros-args -p periodo_s:=1.0

        periodo = self.get_parameter('periodo_s').get_parameter_value().double_value
        # Lê o valor atual do parâmetro.

        self.bridge = CvBridge()
        # Instancia o objeto para ponte entre ROS e OpenCV.

        self.publisher_ = self.create_publisher(String, 'dog_ia/status', 10)
        # Cria o publicador no tópico 'dog_ia/status' com limite de fila 10.
        # Como o nome não começa com '/', ele é relativo ao namespace do nó;
        # sem namespace, o nome final fica '/dog_ia/status'.

        self.pub_imagem = self.create_publisher(Image, 'dog_ia/imagem_teste', 10)
        # Cria o publicador da imagem sintética no tópico 'dog_ia/imagem_teste'.

        self.contador = 0
        # Conta quantas mensagens de status já foram publicadas.

        self.imagem_teste = self.gera_imagem_teste()
        # Gera a imagem sintética usada no autoteste e na publicação.

        self.ponte_ok = self.autoteste_cv_bridge()
        # Executa o autoteste da ponte ROS 2 <-> OpenCV uma única vez.

        self.timer = self.create_timer(periodo, self.publica_status)
        # Configura um temporizador para chamar publica_status a cada 'periodo' segundos.

        if self.ponte_ok:
            self.get_logger().info('✅ Nó de Validação do DOG-IA iniciado com sucesso!')
            # Exibe mensagem no log do terminal confirmando a inicialização.
        else:
            self.get_logger().error('❌ Nó iniciado, mas o autoteste do cv_bridge falhou.')
            # Exibe erro no log se a ponte ROS 2 <-> OpenCV não funcionou.

    @staticmethod
    def gera_imagem_teste():
        """Cria uma imagem BGR 120x160 com um 'semáforo' desenhado."""
        img = np.zeros((120, 160, 3), dtype=np.uint8)
        # Cria uma imagem preta: 120 linhas, 160 colunas, 3 canais (B, G, R).

        cv2.rectangle(img, (60, 10), (100, 110), (60, 60, 60), -1)
        # Desenha a caixa cinza do semáforo (-1 = retângulo preenchido).

        cv2.circle(img, (80, 35), 14, (0, 0, 255), -1)
        # Desenha a luz vermelha (no OpenCV a ordem das cores é B, G, R).

        cv2.circle(img, (80, 85), 14, (0, 255, 0), -1)
        # Desenha a luz verde.

        return img
        # Devolve a matriz numpy.ndarray com a imagem.

    def autoteste_cv_bridge(self):
        """Converte OpenCV -> ROS -> OpenCV e confere se a imagem voltou igual."""
        try:
            msg_img = self.bridge.cv2_to_imgmsg(self.imagem_teste, encoding='bgr8')
            # Converte a matriz do OpenCV em mensagem sensor_msgs/Image.

            volta = self.bridge.imgmsg_to_cv2(msg_img, desired_encoding='bgr8')
            # Converte a mensagem ROS de volta para matriz do OpenCV.

            iguais = bool(np.array_equal(self.imagem_teste, volta))
            # Compara pixel a pixel a imagem original com a convertida.
        except Exception as erro:
            self.get_logger().error(f'Erro no cv_bridge: {erro}')
            return False
            # Qualquer exceção na conversão reprova o autoteste.

        resultado = 'pixels identicos' if iguais else 'PIXELS DIFERENTES'
        # Texto do resultado da comparação.

        self.get_logger().info(
            f'OpenCV {cv2.__version__} | cv_bridge: imagem {msg_img.width}x{msg_img.height} '
            f'({msg_img.encoding}) convertida ida e volta -> {resultado}'
        )
        # Registra a versão do OpenCV e o resultado do autoteste.

        return iguais
        # True se a ponte ROS 2 <-> OpenCV está funcionando.

    def publica_status(self):
        """Publica o status e a imagem de teste (callback do temporizador)."""
        msg = String()
        # Instancia uma nova mensagem do tipo String.

        msg.data = MSG_OK if self.ponte_ok else MSG_FALHA
        # Atribui o conteúdo textual à mensagem, conforme o autoteste.

        self.publisher_.publish(msg)
        # Envia a mensagem para o tópico 'dog_ia/status'.

        msg_img = self.bridge.cv2_to_imgmsg(self.imagem_teste, encoding='bgr8')
        # Converte a imagem de teste para mensagem ROS a cada ciclo.

        msg_img.header.stamp = self.get_clock().now().to_msg()
        # Carimba a mensagem com o horário atual do ROS.

        msg_img.header.frame_id = 'camera_link'
        # Indica o sistema de coordenadas da câmera (usado mais adiante na árvore TF2).

        self.pub_imagem.publish(msg_img)
        # Envia a imagem para o tópico 'dog_ia/imagem_teste'.

        self.contador += 1
        # Incrementa o contador de publicações.

        self.get_logger().info(f'Mensagem Publicada #{self.contador}: "{msg.data}"')
        # Registra no console a confirmação do envio.


def main(args=None):
    """Inicializa o ROS 2, executa o nó e encerra de forma limpa."""
    rclpy.init(args=args)
    # Inicializa as comunicações do ROS 2.

    node = ValidaAmbienteNode()
    # Instancia a classe do nó.

    try:
        rclpy.spin(node)
        # Mantém o nó rodando e aguardando eventos até interrupção (Ctrl+C).
    except KeyboardInterrupt:
        pass
        # Ctrl+C é o jeito normal de parar o nó: não é tratado como erro.
    finally:
        node.destroy_node()
        # Finaliza e destrói o nó.

        if rclpy.ok():
            rclpy.shutdown()
            # Encerra o sistema de comunicação do ROS 2 (se ainda estiver ativo).


if __name__ == '__main__':
    main()
    # Ponto de entrada do script.
