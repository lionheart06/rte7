import kivy
from kivy.app import App

from pyobjus.dylib_manager import load_framework, INCLUDE
load_framework(INCLUDE.AppKit)
load_framework(INCLUDE.Foundation)

from pyobjus import autoclass, protocol 

NSStatusBar = autoclass('NSStatusBar')
NSImage = autoclass('NSImage')

class MyApp(App):

    def build(self):
        statusBar = NSStatusBar.alloc().init()
        self.statusBar = statusBar.systemStatusBar
        print(self.statusBar)
        statusItem = self.statusBar.statusItemWithLength(10)
        statusItem.button.image = NSImage.imageNamed('my_app_icon.png')
        print(self.statusBar)
        

        # Create a status bar item
        #self.status_bar_item = NSStatusBarItem.alloc().init()
        s#elf.status_bar_item.setImage_(NSImage.imageNamed_('my_app_icon.png'))
        #self.status_bar_item.setMenu_(self.menu)
        #self.status_bar_item.setAutoreversesImage_(True)

        # Set the status bar item's title
        #self.status_bar_item.setTitle_('My App')

        # Add the status bar item to the status bar
        #NSStatusBar.systemStatusBar().setStatusBarItem_(self.status_bar_item)

        # Create a Kivy window
        self.window = kivy.uix.label.Label(text='Hello, world!')

        return self.window

    def update_system_tray_text(self, text):
        self.status_bar_item.setTitle_(text)
    def on_quit(self, sender):
        self.window.close()

if __name__ == '__main__':
    MyApp().run()

