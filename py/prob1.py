import libcst as cst
src = "#!/usr/bin/env python\n# -*- coding: utf-8 -*-\n# hello\nimport os\n"
mod = cst.parse_module(src)
class DropAll(cst.CSTTransformer):
    def leave_Comment(self, o, u):
        return cst.RemoveFromParent()
class DropAndEmptyLines(cst.CSTTransformer):
    def leave_Comment(self, o, u):
        return cst.RemoveFromParent()
    def leave_EmptyLine(self, o, u):
        if o.comment is not None and u.comment is None:
            return cst.RemoveFromParent()
        return u
print("---- drop comments only ----")
print(repr(mod.visit(DropAll()).code))
print("---- drop comments + emptied lines ----")
print(repr(mod.visit(DropAndEmptyLines()).code))
src2 = "# a\n# b\n\nx = 1  # tail\n# after\n"
m2 = cst.parse_module(src2)
print("---- src2 raw ----", repr(m2.code))
print("---- src2 drop only ----", repr(m2.visit(DropAll()).code))
print("---- src2 drop+empty ----", repr(m2.visit(DropAndEmptyLines()).code))
print("--- footer:", m2.footer)
src3 = "x = (\n    1  # inner comment\n    + 2\n)\n"
m3 = cst.parse_module(src3)
print("---- parens drop only ----", repr(m3.visit(DropAll()).code))
print("---- parens drop+empty ----", repr(m3.visit(DropAndEmptyLines()).code))
src4 = "# only comment\n# another\n"
m4 = cst.parse_module(src4)
print("---- comment only file ----", repr(m4.visit(DropAndEmptyLines()).code))
src5 = "# only comment, no newline"
m5 = cst.parse_module(src5)
print("---- comment only no nl ----", repr(m5.visit(DropAndEmptyLines()).code))
src6 = "#!/usr/bin/env python3\n"
m6 = cst.parse_module(src6)
print("---- shebang only ----", repr(m6.visit(DropAndEmptyLines()).code))
for s in [
    'def f():\n    """doc"""\n',
    'def f():\n    """doc"""\n    return 1\n',
    'def f(): """doc"""\n',
    'class C:\n    """doc"""\n',
    'class C: """doc"""\n',
    'async def f():\n    """doc"""\n',
    'def f():\n    """doc"""; return 1\n',
    'def f():\n    """doc"""  # type: ignore\n',
    'def f():\n\n    """doc"""\n\n',
    'x = "not a docstring"\n',
    '"""module doc"""\ndef f():\n    """doc"""\n',
]:
    mm = cst.parse_module(s)
    print("SRC:", repr(s))
    if mm.body:
        first = mm.body[0]
        body = getattr(first, "body", None)
        print("   first:", type(first).__name__, "body type:", type(body).__name__)
        if body is not None and hasattr(body, "body"):
            print("   stmts:", [type(x).__name__ for x in body.body])
            if isinstance(body, cst.IndentedBlock) and body.body and isinstance(body.body[0], cst.SimpleStatementLine):
                print("   small:", [type(x).__name__ for x in body.body[0].body])
