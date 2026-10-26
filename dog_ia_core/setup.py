from setuptools import setup

package_name = 'dog_ia_core'

setup(
    name=package_name,
    version='0.1.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Equipe DOG-IA',
    maintainer_email='dogia.equipe@example.com',
    description='Pacote núcleo do DOG-IA: validação do ambiente ROS 2 + OpenCV.',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            # Passo 3 da Etapa 2: registra o executável "valida_ambiente".
            # Formato: <nome_do_executavel> = <pacote>.<modulo>:<funcao>
            'valida_ambiente = dog_ia_core.valida_ambiente:main',
        ],
    },
)
