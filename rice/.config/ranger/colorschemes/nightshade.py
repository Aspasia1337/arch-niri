# Nightshade colorscheme for ranger
# Dark purple/orange palette, matching the niri/waybar setup.
# License: GNU GPL version 3 (derived from ranger's default colorscheme).

from __future__ import (absolute_import, division, print_function)

from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import (
    default, normal, bold, reverse, dim, default_colors,
)

# Palette mapped to the xterm-256 cube
BG        = 233  # #0d0a12  background
FG        = 223  # #e8dcc8  foreground / cream
ORANGE    = 208  # #ff7518  accent
ORANGE_HL = 214  # brighter orange for markers
PURPLE    = 99   # #9b30ff  bright purple
PURPLE_LO = 60   # #5b3a8c  muted purple (progress bar)
GREEN     = 154  # #9dff00  executables / good
RED       = 197  # #ff1a3c  errors / bad
TEAL      = 66   # #4a7c74  links


class Nightshade(ColorScheme):
    progress_bar_color = PURPLE_LO

    def use(self, context):  # noqa  pylint: disable=too-many-branches,too-many-statements
        fg, bg, attr = FG, BG, normal

        if context.reset:
            return default_colors

        elif context.in_browser:
            if context.selected:
                attr = reverse
            else:
                attr = normal
            if context.empty or context.error:
                bg = RED
            if context.border:
                fg = PURPLE_LO
            if context.media:
                fg = PURPLE
            if context.container:
                fg = RED
            if context.directory:
                attr |= bold
                fg = ORANGE
            elif context.executable and not \
                    any((context.media, context.container,
                         context.fifo, context.socket)):
                attr |= bold
                fg = GREEN
            if context.socket:
                attr |= bold
                fg = PURPLE
            if context.fifo or context.device:
                fg = ORANGE
                if context.device:
                    attr |= bold
            if context.link:
                fg = TEAL if context.good else RED
            if context.tag_marker and not context.selected:
                attr |= bold
                fg = ORANGE_HL
            if not context.selected and (context.cut or context.copied):
                attr |= bold | dim
                fg = PURPLE_LO
            if context.main_column:
                if context.selected:
                    attr |= bold
                if context.marked:
                    attr |= bold
                    fg = ORANGE_HL
            if context.badinfo:
                if attr & reverse:
                    bg = RED
                else:
                    fg = RED
            if context.inactive_pane:
                fg = TEAL

        elif context.in_titlebar:
            attr |= bold
            if context.hostname:
                fg = RED if context.bad else GREEN
            elif context.directory:
                fg = ORANGE
            elif context.tab:
                if context.good:
                    bg = PURPLE_LO
            elif context.link:
                fg = TEAL

        elif context.in_statusbar:
            if context.permissions:
                if context.good:
                    fg = TEAL
                elif context.bad:
                    fg = RED
            if context.marked:
                attr |= bold | reverse
                fg = ORANGE_HL
            if context.frozen:
                attr |= bold | reverse
                fg = TEAL
            if context.message:
                if context.bad:
                    attr |= bold
                    fg = RED
            if context.loaded:
                bg = self.progress_bar_color
            if context.vcsinfo:
                fg = PURPLE
                attr &= ~bold
            if context.vcscommit:
                fg = ORANGE
                attr &= ~bold
            if context.vcsdate:
                fg = TEAL
                attr &= ~bold

        if context.text:
            if context.highlight:
                attr |= reverse

        if context.in_taskview:
            if context.title:
                fg = ORANGE
            if context.selected:
                attr |= reverse
            if context.loaded:
                if context.selected:
                    fg = self.progress_bar_color
                else:
                    bg = self.progress_bar_color

        if context.vcsfile and not context.selected:
            attr &= ~bold
            if context.vcsconflict:
                fg = PURPLE
            elif context.vcsuntracked:
                fg = TEAL
            elif context.vcschanged:
                fg = RED
            elif context.vcsunknown:
                fg = RED
            elif context.vcsstaged:
                fg = GREEN
            elif context.vcssync:
                fg = GREEN
            elif context.vcsignored:
                fg = default

        elif context.vcsremote and not context.selected:
            attr &= ~bold
            if context.vcssync or context.vcsnone:
                fg = GREEN
            elif context.vcsbehind:
                fg = RED
            elif context.vcsahead:
                fg = PURPLE
            elif context.vcsdiverged:
                fg = PURPLE
            elif context.vcsunknown:
                fg = RED

        return fg, bg, attr
