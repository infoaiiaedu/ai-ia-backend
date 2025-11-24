const PLUGIN_NAME = "audioWidget";

tinymce.PluginManager.add(PLUGIN_NAME, function (editor, url) {
    const openDialog = function () {
        return editor.windowManager.open({
            title: "Palitra აუდიო პლაგინი",
            body: {
                type: "panel",
                items: [
                    {
                        name: "audioSrc",
                        type: "urlinput",
                        filetype: "media",
                        label: "აუდიო ფაილი"
                    },
                    {
                        type: "checkbox",
                        name: "autoPlay",
                        label: "ავტომატური დაკვრა <p style='color: #b20000;; display: inline-block;font-weight: bold;'>(ჩაურთეთ მხოლოდ 1 აუდიოს)</p>",
                        checked: true
                    },
                    {
                        type: "checkbox",
                        name: "showCaption",
                        label: "გამოუჩნდეს caption",
                        checked: true
                    },
                    {
                        type: "textarea",
                        name: "captionContent",
                        label: "caption"
                    }
                ]
            },
            buttons: [
                {
                    type: "cancel",
                    text: "გათიშვა"
                },
                {
                    type: "submit",
                    text: "დამახსოვრება",
                    primary: true
                }
            ],
            onSubmit: function (api) {
                let data = api.getData();

                const { showCaption, captionContent, autoPlay } = data;

                const audioSrc = data.audioSrc.value;
                if (!audioSrc)
                    return editor.windowManager.alert("შეიყვანეთ აუდიო");

                if (showCaption && !!!captionContent.length)
                    return editor.windowManager.alert(
                        "შეიყვანეთ caption!! ჩართულია caption, მაგრამ კონტენტი ცარიელია"
                    );

                let audioHtml = autoPlay
                    ? `<audio controls autoplay`
                    : `<audio controls`;

                audioHtml += ` src="${audioSrc}"></audio>`;

                let captionHtml = null;

                if (
                    showCaption ||
                    (!showCaption && captionContent.length >= 1)
                ) {
                    captionHtml = `<figcaption class='plt-audio-widget__caption'>
                        ${captionContent}
                    </figcaption>`;
                }

                const html = `<figure class="plt-audio-widget">
                    <div class='plt-audio-widget__audio'> ${audioHtml}</div>
                        ${captionHtml}
                    </figure>
                <p>&nbsp;</p>`;
                editor.insertContent(html);

                api.close();
            }
        });
    };

    editor.ui.registry.addButton(PLUGIN_NAME, {
        text: "Audio პლაგინი",
        shortcut: "meta+alt+N",
        onAction: function () {
            openDialog(editor);
        }
    });

    editor.shortcuts.add("meta+33", PLUGIN_NAME, function () {
        openDialog(editor);
    });

    return {
        getMetadata() {
            return {
                name: PLUGIN_NAME
            };
        }
    };
});
