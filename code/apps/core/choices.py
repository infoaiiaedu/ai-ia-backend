from string import ascii_uppercase


PostionChoices = [(p, f"{p} ჯგუფი") for p in ascii_uppercase]


PageChoices = [
    ("home", "მთავარი"),
    ("category", "კატეგორიის გვერდი"),
    ("tag", "ტეგების გვერდი"),
    ("article", "სტატიის გვერდი"),
    ("gallery", "გალერეის გვერდი"),
    ("specprojects", "სპეცპროექტების გვერდი"),
    ("specproject", "სპეცპროექტის შიდა გვერდი"),
    ("search", "ძიების გვერდი"),
    ("author", "ავტორის გვერდი"),
]


LAYOUT_CHOICES = [
    ("default", "სტანდარტული"),
    ("specproject", "სპეცპროექტი"),
]

COLOR_CHOICES = [
    ("red", "წითელი"),
    ("green", "მწვანე"),
    ("blue", "ლურჯი"),
    ("yellow", "ყვითელი"),
    ("black", "შავი"),
    ("white", "თეთრი"),
]
