# dmgbuild settings: app on the left, Applications shortcut on the right.
# `defines` is injected by dmgbuild (-D app=path/to/App.app).
import os

app = defines["app"]  # noqa: F821
name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}

# Window is 600x380; icon centers sit on one row, app at 160, Applications at 440.
window_rect = ((200, 120), (600, 380))
icon_locations = {name: (160, 180), "Applications": (440, 180)}
default_view = "icon-view"
icon_size = 128
text_size = 13
show_toolbar = False
show_status_bar = False
show_sidebar = False
