import subprocess

CMD = '''
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
'''

def notify(title, text):
  subprocess.call(['osascript', '-e', CMD, title, text])

# Example uses:
notify("Title", "Heres an alert")
notify(r'Weird\/|"!@#$%^&*()\ntitle', r'!@#$%^&*()"')
