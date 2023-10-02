import os
import datetime
from pynput.keyboard import Listener
from rumps import App, Timer, Window, MenuItem
from stats import Stats


log = []
WORKDURATION=30

def getTimeString():
   now = datetime.datetime.now()
   t = now.strftime("%B %d, %H:%M")
   return t

def popup(value):   
   if testApp != None:
      testApp.root.parent.show()
      os.system('osascript -e \'display notification "hello world!" with title "This is the title" sound name "Submarine"\'')
      t = getTimeString()
      log.append(f'{t} Popup')
      s = ''
      for l in log:
         s += f'{l}\n'
      testApp.l.text = s


def callback(instance):
    t = getTimeString()
    log.append(f'{t} Hide')
    instance.parent.parent.hide()
    s = ''
    for l in log:
      s += f'{l}\n'
    testApp.l.text = s


class MainApp():
   def __init__(self):
      super().__init__()
      self.count = WORKDURATION
      self.resumeCount = False
      self.status = "running"
      self.app = App('rte7')
      self.timer = Timer(self.on_tick, 60)
      self.stats = Stats()
      self.app.menu = self.stats.getMenuItems()
   
   def run(self):
      Listener(on_press = self.on_press).start()
      self.timer.start()
      self.app.run()
   
   def on_tick(self, sender):
      if self.resumeCount:
         self.count = self.count - 1
         self.resumeCount = False
      if self.count <= 0: 
         self.popup()
         self.count = WORKDURATION
      self.app.title = str(self.count)
      if self.resumeCount:
         self.status = 'RUNNING'
      else:
         self.status = 'PAUSED'
   
   def on_press(self,key):
      self.resumeCount = True
      self.status = 'RUNNING'

   def popup(self):
      self.stats.update()
      self.app.menu.clear()
      self.app.menu = self.stats.getMenuItems()
      #TODO change the below line to use rumps notificatio
      os.system('osascript -e \'display notification "Take a coffee break!" with title "Break Time" sound name "Submarine"\'')
      Window(f"Work Periods: TODO add the UI for stats").run()

if __name__ == '__main__':
    global testApp
    testApp = MainApp()
    testApp.run()
