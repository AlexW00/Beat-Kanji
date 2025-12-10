"""UI components for beatmap editor."""


# Defer import to avoid circular dependencies
def get_app():
    from ui.app import BeatmapEditorApp

    return BeatmapEditorApp


__all__ = ["get_app"]
