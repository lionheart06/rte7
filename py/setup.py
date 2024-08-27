from setuptools import setup
APP=['main.py']
OPTIONS= {
        'argv_emulation':True,
        'includes': ['pynput'],
        }

REQUIREMENTS=[
        "pynput"
        ]

setup(
        app=APP,
        options={'py2app':OPTIONS},
        setup_requires=['py2app'],
        install_requires=REQUIREMENTS
        )
