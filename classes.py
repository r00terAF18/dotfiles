from datetime import date
import calendar
from prettytable import PrettyTable

today = calendar.day_name[date.today().weekday()]
myTable = PrettyTable(["Class", "Time", "Link"])

if today == "Saturday":
    myTable.add_row(["Statistic and Probability", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/shahsanaii"])
    myTable.add_row(["Electrical Circuites", "12 - 14", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
    myTable.add_row(["Engineer Maths", "18 - 20", "https://www.skyroom.online/ch/shhut.ac.ir/chaji"])
elif today == "Sunday":
    myTable.add_row(["Electromangnatism", "16 - 18", "https://www.skyroom.online/ch/shhut.ac.ir/mazraeh-fard"])
elif today == "Monday":
    myTable.add_row(["Electrical Circuites", "12 - 14", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
    myTable.add_row(["Sport 1", "14 - 16", "https://www.skyroom.online/ch/shhut.ac.ir/darvakh"])
    myTable.add_row(["Electrical Language", "18 - 20", "https://www.skyroom.online/ch/shhut.ac.ir/erfani"])
elif today == "Tuesday":
    myTable.add_row(["Engineer Maths", "08 - 10", "https://www.skyroom.online/ch/shhut.ac.ir/chaji"])
    myTable.add_row(["Statistic and Probability", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/shahsanaii"])
    myTable.add_row(["Islamic Revolution", "14 - 16", "https://www.skyroom.online/ch/shhut.ac.ir/darvakh"])
    myTable.add_row(["Electromangnatism", "16 - 18", "https://www.skyroom.online/ch/shhut.ac.ir/mazraeh-fard"])
elif today == "Wednesday":
    myTable.add_row(["Number Calculations", "08 - 10", "https://www.skyroom.online/ch/shhut.ac.ir/pouyan"])
    myTable.add_row(["Number Calculations", "10 - 12", "https://www.skyroom.online/ch/shhut.ac.ir/keramat"])


print(myTable)