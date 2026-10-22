function resolveIcon(icon, resolver) {
    if (!icon) return "";
    if (icon[0] === "/") return "file://" + icon;
    if (/^(file|image|data|https?):/.test(icon)) return icon;
    return resolver(icon, true);
}
