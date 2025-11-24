tinymce.PluginManager.add("insertArticle", function (editor, url) {
    editor.ui.registry.addButton("insertArticle", {
        text: "<strong>A</strong>",
        onAction: function () {
            window.insertArticle = (val) => {
                const title = val.title.replace(/"/g, "");

                editor.insertContent(`
                <div class="article_attach">
                    <img src="${val.image}" title="${title}" />
                    <a href="${val.url}">${title}</a>
                </div><p>&nbsp;</p>`);

                console.log(val);
            };

            let w = window.open(
                "/admin/Podcast/Podcast/",
                "",
                "width=1000,height=600"
            );
        }
    });

    return {
        getMetadata() {
            return {
                name: "Insert Podcast"
            };
        }
    };
});
