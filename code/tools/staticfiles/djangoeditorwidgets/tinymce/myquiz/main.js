tinymce.PluginManager.add("myquiz", function (editor, url) {
    let openDialog = function () {
        return editor.windowManager.open({
            title: "My Quiz input dialog",
            body: {
                type: "panel",
                items: [
                    {
                        type: "input",
                        name: "quiz_uid",
                        label: "შეიყვანე გამოკითხვის იდენთიფიკატორი"
                    }
                ]
            },
            buttons: [
                {
                    type: "cancel",
                    text: "Close"
                },
                {
                    type: "submit",
                    text: "Save",
                    primary: true
                }
            ],
            onSubmit: function (api) {
                let data = api.getData();

                let uid = data.quiz_uid;

                editor.insertContent(`
                <div
                    class="palettepq_container"
                    data-href="https://myquiz.ge/quiz/view/${uid}/"
                    data-palettepq="${uid}">
                    <span style="display: none;">myquiz</span>
                </div><p>&nbsp;</p>`);

                api.close();
            }
        });
    };

    console.log("hey");

    editor.ui.registry.addButton("myquiz", {
        text: "<strong>Q</strong>",
        onAction: function () {
            openDialog();
        }
    });

    return {
        getMetadata() {
            return {
                name: "My Quiz"
            };
        }
    };
});
