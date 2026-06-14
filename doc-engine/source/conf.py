# Configuration file for the Sphinx documentation builder for dotfiles.
import os
import shutil

version = os.popen("git -C . describe --tags --always --dirty").read().rstrip()

project = "dotfiles"
copyright = "2024–2026, Michael Weitner"
author = "Michael Weitner"

release = version

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinx.ext.viewcode",
    "myst_parser",
    "sphinxcontrib.plantuml",
    "sphinxcontrib.mermaid",
]

myst_heading_anchors = 6

source_suffix = {
    ".md": "markdown",
    ".rst": "restructuredtext",
}


def _resolve_plantuml_command() -> str:
    if shutil.which("plantuml"):
        return "plantuml"

    java_cmd = shutil.which("java")
    jar_candidates = [
        "/usr/share/plantuml/plantuml.jar",
        "/usr/share/java/plantuml.jar",
        "/usr/share/java/plantuml/plantuml.jar",
    ]

    if java_cmd:
        for jar_path in jar_candidates:
            if os.path.exists(jar_path):
                return f'{java_cmd} -Djava.awt.headless=true -jar "{jar_path}"'

    return "plantuml"


plantuml = _resolve_plantuml_command()

templates_path = ["_templates"]

exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

html_theme = "furo"
html_title = f"{project} ({release})"
html_static_path = ["_static"]

todo_include_todos = True
