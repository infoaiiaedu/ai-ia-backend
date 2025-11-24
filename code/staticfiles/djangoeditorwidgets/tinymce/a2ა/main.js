tinymce.PluginManager.add("a2ა", function (editor, url) {
    const ka = "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ";
    const en = "abgdevzTiklmnopJrstufqRySCcZwWxjh";

    const en2ka = Array.from(en).reduce(
        (m, a, i) => ({ ...m, [a]: ka[i], [ka[i]]: a }),
        {}
    );

    function Convert(editor) {
        const text = editor.selection.getContent({ format: "html" });
        let istag = false;

        let result = "";
        let amp = false;

        Array.from(text).forEach((letter) => {
            let l = letter;
            if (letter == "<") {
                istag = true;
            } else if (letter == ">") {
                istag = false;
            } else if (letter == "&") {
                amp = true;
            } else if (letter == ";" && amp) {
                amp = false;
            } else if (!istag && !amp) {
                l = en2ka[l] || l;
            }

            result += l;
        });

        editor.selection.setContent(result, { format: "html" });
    }

    editor.ui.registry.addButton("a2ა", {
        text: "a2ა",
        shortcut: "meta+alt+U",
        onAction: function () {
            Convert(editor);
        },
    });

    editor.shortcuts.add("meta+32", "a2ა", function () {
        Convert(editor);
    });

    return {
        getMetadata() {
            return {
                name: "a2ა",
            };
        },
    };
});
