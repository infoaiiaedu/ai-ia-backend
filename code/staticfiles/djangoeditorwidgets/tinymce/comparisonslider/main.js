tinymce.PluginManager.add("comparisonslider", function (editor, url) {
    let openDialog = function () {
        return editor.windowManager.open({
            title: "Comparison Slider",
            body: {
                type: "panel",
                items: [
                    {
                        name: "src1",
                        type: "urlinput",
                        filetype: "image",
                        label: "Before",
                    },
                    {
                        name: "src2",
                        type: "urlinput",
                        filetype: "image",
                        label: "After",
                    },
                ],
            },
            buttons: [
                {
                    type: "cancel",
                    text: "Close",
                },
                {
                    type: "submit",
                    text: "Save",
                    primary: true,
                },
            ],
            onSubmit: function (api) {
                let data = api.getData();

                editor.insertContent(`
                <div class="comparison-slider img-comp-container" contenteditable="false">
                    <div class="img-comp-img">
                        <img src="${data.src1.value}" />
                    </div>
                    <div class="img-comp-img">
                        <img src="${data.src2.value}" />
                    </div>
                </div>
                <p>&nbsp;</p>`);

                api.close();
            },
        });
    };

    editor.ui.registry.addButton("comparisonslider", {
        text: "SLIDER",
        onAction: function () {
            openDialog();
        },
    });

    // editor.ui.registry.addMenuItem("comparisonslider", {
    //     text: "Comparison Slider",
    //     onAction() {
    //         openDialog();
    //     },
    // });

    return {
        getMetadata() {
            return {
                name: "Comparison Slider",
            };
        },
    };
});
