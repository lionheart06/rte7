from rumps import MenuItem, quit_application
from datetime import datetime
import math
import random

def quit(_):
   quit_application()

class Stats:
   def __init__(self):
      today = datetime.now().weekday()
      self.periodCounts = [0] * (today + 1)
      self.average = 5
   
   def calculateAverage(self):
      today = datetime.now().weekday()
      # how many days do we have
      days = len(self.periodCounts)
      if (days == 0):
         return 5

      sum = 0.0
      for n in self.periodCounts:
         if (n == 0):
            n = 5
         sum += n
      
      avg = sum/5
      if (avg == 0):
         avg = 5
      
      return avg

   def getMenuItems(self):
      items = []
      for index,element in enumerate(self.periodCounts):
         items.append(MenuItem(f'{self.getDayFromIdx(index)} {element} of {self.average}'))
      items.append(MenuItem('Quit', callback=quit))
      return items

   def getDayFromIdx(self, idx):
      today = datetime.now().weekday()
      ret = ''
      if (idx == 0):
         ret = 'Mon'
      elif idx== 1:
         ret = 'Tue'
      elif idx == 2:
         ret = 'Wed'
      elif idx == 3:
         ret = 'Thu'
      elif idx == 4:
         ret = 'Fri'
      if (today == idx):
         ret = ret + '*'
      return ret

   def getRandomNumber(self):
      return math.ceil(random.random() * 62)
      
   def update(self):
      self.calculateAverage()
      today = datetime.now().weekday()
      print(f'today is {today}')
      if today < len(self.periodCounts) - 1:
         print(f'Removing {len(self.periodCounts) - 1}')
         self.periodCounts.pop()

      if today > len(self.periodCounts) - 1:
         print(f'Extending the array by: {today - (len(self.periodCounts)-1)}')
         self.periodCounts.extend([0]*(today - (len(self.periodCounts)-1)))
      
      self.periodCounts[today] = self.periodCounts[today] + 1

   def render(self):
      text = ''
      for index,element in enumerate(self.periodCounts):
         text += f'{self.getDayFromIdx(index)} {element}\n'
      text = self.getRandomNumber()
      return text