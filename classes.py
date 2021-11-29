from datetime import date
import calendar
from prettytable import PrettyTable

today = calendar.day_name[date.today().weekday()]
sa_table = PrettyTable(["Class", "Time", "Link"])
su_table = PrettyTable(["Class", "Time", "Link"])
mo_table = PrettyTable(["Class", "Time", "Link"])
tu_table = PrettyTable(["Class", "Time", "Link"])
we_table = PrettyTable(["Class", "Time", "Link"])

sa_table.add_row(["Statistic and Probability", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/shahsanaii"])
sa_table.add_row(["Electrical Circuites", "12 - 14", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
sa_table.add_row(["Engineer Maths", "18 - 20", "https://www.skyroom.online/ch/shhut.ac.ir/chaji"])
su_table.add_row(["Electromangnatism", "16 - 18", "https://www.skyroom.online/ch/shhut.ac.ir/mazraeh-fard"])
mo_table.add_row(["Electrical Circuites", "12 - 14", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
mo_table.add_row(["Sport 1", "14 - 16", "https://www.skyroom.online/ch/shhut.ac.ir/darvakh"])
mo_table.add_row(["Electrical Language", "18 - 20", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
tu_table.add_row(["Engineer Maths", "08 - 10", "https://www.skyroom.online/ch/shhut.ac.ir/chaji"])
tu_table.add_row(["Statistic and Probability", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/shahsanaii"])
tu_table.add_row(["Islamic Revolution", "14 - 16", "https://www.skyroom.online/ch/shhut.ac.ir/darvakh"])
tu_table.add_row(["Electromangnatism", "16 - 18", "https://www.skyroom.online/ch/shhut.ac.ir/mazraeh-fard"])
we_table.add_row(["Number Calculations", "08 - 10", "https://www.skyroom.online/ch/shhut.ac.ir/pouyan"])
we_table.add_row(["Number Calculations", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/keramat"])


print(">>> Saturday <<<")
print(sa_table)
print(">>> Sunday <<<")
print(su_table)
print(">>> Monday <<<")
print(mo_table)
print(">>> Thursday <<<")
print(tu_table)
print(">>> Wednsaday <<<")
print(we_table)
