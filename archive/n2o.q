You are an expert Python packaging engineer.
Context:
- I have an existing Python project with a pyproject.toml already present.
- I need you to generate a setup.py file for this project.
- Project root: current folder
- Target Python version(s): [ >=3.9]
- Build backend declared in pyproject.toml: one of [setuptools.build_meta, poetry-core, hatchling, flit_core, pdm-backend]
Task:
Generate a setup.py that is consistent with the existing pyproject.toml.
Rules:
1. If the build backend is setuptools and pyproject.toml already contains all metadata, generate the minimal shim:
   from setuptools import setup
   setup()
   Do not duplicate metadata from pyproject.toml.
2. If extra setup.py logic is required (e.g., custom cmdclass, C extensions, package_data, scripts, entry_points not expressible in pyproject.toml), include only that logic. Read all other config from pyproject.toml. Do not copy static metadata unless absolutely unavoidable.
3. If the build backend is not setuptools (poetry-core, hatchling, flit_core, pdm-backend, etc.), do NOT generate a setup.py. Instead explain why it is incompatible and suggest alternatives.
4. Do not invent dependencies, versions, URLs, classifiers, package names, or entry points.
5. Use modern setuptools practices. Avoid deprecated setup_requires, tests_require, and use_2to3.
6. Preserve compatibility with [target Python version].
7. Add brief comments explaining any non-obvious logic.
8. Ensure the result supports pip install -e . and python -m build if applicable.
Output:
· First, provide the complete setup.py in a code block.
· Then, a short section titled "Assumptions / Notes" listing any assumptions and any changes I should make.
· If you need more files or information, ask for them before generating.
