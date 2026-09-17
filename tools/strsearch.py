import sys, zipfile, re
sys.argv_ = sys.argv
JAR = "/Users/blanc/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/projectzomboid.jar"
pat = sys.argv[1].encode()
with zipfile.ZipFile(JAR) as z:
    for n in z.namelist():
        if n.endswith('.class'):
            d = z.read(n)
            if pat in d: print(n)
