class PathAlias {
    [string] $Text
    [string] $Color

    PathAlias() {}

    PathAlias([string]$text, [string]$color) {
        $this.Text = $text
        $this.Color = $color
    }
}
