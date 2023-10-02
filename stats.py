from rumps import MenuItem
from datetime import datetime

class Stats:
   def __init__(self):
      today = datetime.now().weekday()
      self.periodCounts = [0] * (today + 1)

   def getMenuItems(self):
      items = []
      for index,element in enumerate(self.periodCounts):
         items.append(MenuItem(f'{self.getDayFromIdx(index)} {element}'))
      return items

   def getDayFromIdx(self, idx):
      if (idx == 0):
         return 'Mon'
      elif idx== 1:
         return 'Tue'
      elif idx == 2:
         return 'Wed'
      elif idx == 3:
         return 'Thu'
      elif idx == 4:
         return 'Fri'
      
   def update(self):
      today = datetime.now().weekday()
      if today > len(self.periodCounts) - 1:
         self.periodCounts.extend([0]*(today - len(self.periodCounts) -1))
      
      self.periodCounts[today] = self.periodCounts[today] + 1
