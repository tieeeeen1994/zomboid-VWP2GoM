#!/usr/bin/env python3
"""Minimal javap replacement. Usage:
  jdis.py <class path in jar, e.g. zombie/inventory/InventoryItem>            -> list fields + methods
  jdis.py <class> <methodName>                                                   -> disassemble methods with that name
"""
import struct, sys, zipfile

JAR = "/Users/blanc/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/projectzomboid.jar"

OPS = {}
def op(code, name, fmt=""):
    OPS[code] = (name, fmt)
simple = """nop aconst_null iconst_m1 iconst_0 iconst_1 iconst_2 iconst_3 iconst_4 iconst_5 lconst_0 lconst_1 fconst_0 fconst_1 fconst_2 dconst_0 dconst_1""".split()
for i, n in enumerate(simple): op(i, n)
op(0x10, "bipush", "b"); op(0x11, "sipush", "h"); op(0x12, "ldc", "c1"); op(0x13, "ldc_w", "c2"); op(0x14, "ldc2_w", "c2")
for i, n in enumerate("iload lload fload dload aload".split()): op(0x15 + i, n, "B")
names = []
for t in "ilfda":
    for k in range(4): names.append(f"{t}load_{k}")
for i, n in enumerate(names): op(0x1a + i, n)
for i, n in enumerate("iaload laload faload daload aaload baload caload saload".split()): op(0x2e + i, n)
for i, n in enumerate("istore lstore fstore dstore astore".split()): op(0x36 + i, n, "B")
names = []
for t in "ilfda":
    for k in range(4): names.append(f"{t}store_{k}")
for i, n in enumerate(names): op(0x3b + i, n)
rest = "iastore lastore fastore dastore aastore bastore castore sastore pop pop2 dup dup_x1 dup_x2 dup2 dup2_x1 dup2_x2 swap iadd ladd fadd dadd isub lsub fsub dsub imul lmul fmul dmul idiv ldiv fdiv ddiv irem lrem frem drem ineg lneg fneg dneg ishl lshl ishr lshr iushr lushr iand land ior lor ixor lxor".split()
for i, n in enumerate(rest): op(0x4f + i, n)
op(0x84, "iinc", "Bb")
conv = "i2l i2f i2d l2i l2f l2d f2i f2l f2d d2i d2l d2f i2b i2c i2s lcmp fcmpl fcmpg dcmpl dcmpg".split()
for i, n in enumerate(conv): op(0x85 + i, n)
br = "ifeq ifne iflt ifge ifgt ifle if_icmpeq if_icmpne if_icmplt if_icmpge if_icmpgt if_icmple if_acmpeq if_acmpne goto jsr".split()
for i, n in enumerate(br): op(0x99 + i, n, "j")
op(0xa9, "ret", "B")
op(0xaa, "tableswitch", "T"); op(0xab, "lookupswitch", "L")
for i, n in enumerate("ireturn lreturn freturn dreturn areturn return".split()): op(0xac + i, n)
for i, n in enumerate("getstatic putstatic getfield putfield invokevirtual invokespecial invokestatic".split()): op(0xb2 + i, n, "c2")
op(0xb9, "invokeinterface", "c2BB"); op(0xba, "invokedynamic", "c2BB")
op(0xbb, "new", "c2"); op(0xbc, "newarray", "B"); op(0xbd, "anewarray", "c2")
for i, n in enumerate("arraylength athrow".split()): op(0xbe + i, n)
op(0xc0, "checkcast", "c2"); op(0xc1, "instanceof", "c2")
op(0xc2, "monitorenter"); op(0xc3, "monitorexit")
op(0xc4, "wide", "W"); op(0xc5, "multianewarray", "c2B")
op(0xc6, "ifnull", "j"); op(0xc7, "ifnonnull", "j")
op(0xc8, "goto_w", "J"); op(0xc9, "jsr_w", "J")


class CF:
    def __init__(self, data):
        self.d = data; self.p = 8
        n = self.u2(); self.cp = [None] * n; i = 1
        while i < n:
            t = self.u1()
            if t == 1:
                l = self.u2(); self.cp[i] = ("utf", self.d[self.p:self.p + l].decode("utf8", "replace")); self.p += l
            elif t in (3, 4): self.cp[i] = ("num", struct.unpack(">i" if t == 3 else ">f", self.d[self.p:self.p + 4])[0]); self.p += 4
            elif t in (5, 6):
                self.cp[i] = ("num", struct.unpack(">q" if t == 5 else ">d", self.d[self.p:self.p + 8])[0]); self.p += 8; i += 1
            elif t in (7, 8, 16, 19, 20): self.cp[i] = (t, self.u2())
            elif t in (9, 10, 11, 12, 17, 18): self.cp[i] = (t, self.u2(), self.u2())
            elif t == 15: self.cp[i] = (t, self.u1(), self.u2())
            i += 1
        self.u2(); self.this = self.s(self.u2()); self.sup = self.s(self.u2())
        n_if = self.u2(); self.p += 2 * n_if
        self.fields = [self.member() for _ in range(self.u2())]
        self.methods = [self.member() for _ in range(self.u2())]

    def u1(self): v = self.d[self.p]; self.p += 1; return v
    def u2(self): v = struct.unpack(">H", self.d[self.p:self.p + 2])[0]; self.p += 2; return v
    def u4(self): v = struct.unpack(">I", self.d[self.p:self.p + 4])[0]; self.p += 4; return v

    def member(self):
        acc = self.u2(); name = self.s(self.u2()); desc = self.s(self.u2()); attrs = {}
        for _ in range(self.u2()):
            an = self.s(self.u2()); l = self.u4(); attrs[an] = self.d[self.p:self.p + l]; self.p += l
        return acc, name, desc, attrs

    def s(self, i):
        e = self.cp[i]
        if e is None: return "?"
        if e[0] == "utf": return e[1]
        if e[0] == "num": return repr(e[1])
        t = e[0]
        if t in (7, 8, 16, 19, 20): return self.s(e[1]) if t != 8 else '"' + self.s(e[1]) + '"'
        if t in (9, 10, 11): return self.s(e[1]) + "." + self.s(e[2])
        if t == 12: return self.s(e[1]) + ":" + self.s(e[2])
        if t in (17, 18): return "indy#" + str(e[1]) + ":" + self.s(e[2])
        if t == 15: return "mh:" + self.s(e[2])
        return "?"


def disasm(cf, code):
    maxs, maxl, clen = struct.unpack(">HHI", code[:8]); c = code[8:8 + clen]; pc = 0; out = []
    while pc < len(c):
        o = c[pc]; name, fmt = OPS.get(o, (f"op{o:#x}", "")); start = pc; pc += 1; args = []
        if fmt == "b": args.append(struct.unpack(">b", c[pc:pc + 1])[0]); pc += 1
        elif fmt == "h": args.append(struct.unpack(">h", c[pc:pc + 2])[0]); pc += 2
        elif fmt == "B": args.append(c[pc]); pc += 1
        elif fmt == "Bb": args += [c[pc], struct.unpack(">b", c[pc + 1:pc + 2])[0]]; pc += 2
        elif fmt == "c1": args.append(cf.s(c[pc])); pc += 1
        elif fmt == "c2": args.append(cf.s(struct.unpack(">H", c[pc:pc + 2])[0])); pc += 2
        elif fmt == "c2BB": args.append(cf.s(struct.unpack(">H", c[pc:pc + 2])[0])); pc += 4
        elif fmt == "c2B": args.append(cf.s(struct.unpack(">H", c[pc:pc + 2])[0])); pc += 3
        elif fmt == "j": args.append("->" + str(start + struct.unpack(">h", c[pc:pc + 2])[0])); pc += 2
        elif fmt == "J": args.append("->" + str(start + struct.unpack(">i", c[pc:pc + 4])[0])); pc += 4
        elif fmt == "T":
            pc += (4 - pc % 4) % 4
            dflt, lo, hi = struct.unpack(">iii", c[pc:pc + 12]); pc += 12
            tg = [start + struct.unpack(">i", c[pc + 4 * k:pc + 4 * k + 4])[0] for k in range(hi - lo + 1)]; pc += 4 * (hi - lo + 1)
            args.append(f"default->{start + dflt} {lo}..{hi} {tg}")
        elif fmt == "L":
            pc += (4 - pc % 4) % 4
            dflt, n = struct.unpack(">ii", c[pc:pc + 8]); pc += 8
            pairs = [struct.unpack(">ii", c[pc + 8 * k:pc + 8 * k + 8]) for k in range(n)]; pc += 8 * n
            args.append(f"default->{start + dflt} " + " ".join(f"{k}->{start + v}" for k, v in pairs))
        elif fmt == "W":
            o2 = c[pc]; pc += 1; idx = struct.unpack(">H", c[pc:pc + 2])[0]; pc += 2
            if o2 == 0x84: pc += 2
            args.append(f"{OPS.get(o2, ('?',))[0]} {idx}")
        out.append(f"  {start:5d}: {name} {' '.join(map(str, args))}")
    p = 8 + clen
    ne = struct.unpack(">H", code[p:p+2])[0]; p += 2
    for k in range(ne):
        a,b,h,t = struct.unpack(">HHHH", code[p:p+8]); p += 8
        out.append(f"  EXC [{a},{b}) -> {h} {cf.s(t) if t else 'any'}")
    return "\n".join(out)


def main():
    cls = sys.argv[1].replace(".", "/")
    with zipfile.ZipFile(JAR) as z:
        cf = CF(z.read(cls + ".class"))
    if len(sys.argv) == 2:
        print(f"class {cf.this} extends {cf.sup}")
        for acc, n, d, _ in cf.fields: print(f"  field {n} {d}  acc={acc:#x}")
        for acc, n, d, _ in cf.methods: print(f"  method {n}{d}  acc={acc:#x}")
        return
    for acc, n, d, a in cf.methods:
        if (n == sys.argv[2] or sys.argv[2] == "ALL") and "Code" in a:
            print(f"== {n}{d}"); print(disasm(cf, a["Code"]))


main()
