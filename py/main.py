import os
import datetime
from pynput.keyboard import Listener
from rumps import App, Timer, Window, MenuItem


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
      self.periodCount = 0
      self.average = MenuItem(self.periodCount)
      self.app.menu = [self.average]
   
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
      self.periodCount = self.periodCount + 1
      self.average.title = self.periodCount
      os.system('osascript -e \'display notification "Take a coffee break!" with title "Break Time" sound name "Submarine"\'')
      Window(f"Work Periods: {self.periodCount}").run()

if __name__ == '__main__':
    global testApp
    testApp = MainApp()
    testApp.run()
