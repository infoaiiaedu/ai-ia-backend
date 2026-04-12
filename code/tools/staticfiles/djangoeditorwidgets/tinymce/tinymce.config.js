function getCsrfToken() {
    var match = document.cookie.match(/csrftoken=([^;]+)/);
    if (match) return match[1];
    var el = document.querySelector('[name=csrfmiddlewaretoken]');
    return el ? el.value : '';
}

const tinymceConfig = ({
    name,
    media_upload_url,
    media_manager_url,
    images_upload_url,
    browseFiles
}) => {
    const uploadUrl = images_upload_url || '/admin/tinymce-upload/';

    let config = {
        selector: `textarea[data-tinymce="${name}"]`,
        deprecation_warnings: false,
        height: 500,
        // paste_as_text: true,
        force_p_newlines: true,
        invalid_elements: "br",
        cleanup: true,
        menubar: true,
        contextmenu: false,
        fontsize_width: 30,
        content_css: [
            "/static/djangoeditorwidgets/tinymce/a2ა/main.css",
            "/static/djangoeditorwidgets/tinymce/comparisonslider/main.css",
            "/static/djangoeditorwidgets/tinymce/myquiz/main.css",
            "/static/djangoeditorwidgets/tinymce/insert-Podcast/main.css"
        ],
        external_plugins: {
            insertArticle:
                "/static/djangoeditorwidgets/tinymce/insert-Podcast/main.js",
            myquiz: "/static/djangoeditorwidgets/tinymce/myquiz/main.js",
            a2ა: "/static/djangoeditorwidgets/tinymce/a2ა/main.js",
            audioWidget:
                "/static/djangoeditorwidgets/tinymce/audio-widget/main.js",
            comparisonslider:
                "/static/djangoeditorwidgets/tinymce/comparisonslider/main.js"
        },
        pagebreak_separator: '<hr class="system-pagebreak" />',
        plugins: [
            "advlist",
            "autolink",
            "lists",
            "link",
            "image",
            "charmap",
            "print",
            "preview",
            "anchor",
            "searchreplace",
            "visualblocks",
            "code",
            "fullscreen",
            "imagetools",
            "codesample",
            "pagebreak",
            "insertdatetime",
            "media",
            "table",
            "paste",
            "code",
            "help",
            "wordcount",
            "myquiz",
            "comparisonslider",
            "a2ა",
            "audioWidget",
            "insertArticle"
        ],
        toolbar: `
            insertfile undo redo | styleselect | fontsizeselect |  forecolor backcolor
            | bold italic underline | alignleft aligncenter alignright alignjustify
            | bullist numlist outdent indent
            | link media image browse | insertArticle myquiz pagebreak codesample | fullscreen | comparisonslider | a2ა `,
        image_caption: true,
        relative_urls: false,
        automatic_uploads: true,
        images_upload_handler: function (blobInfo, success, failure) {
            var formData = new FormData();
            formData.append('file', blobInfo.blob(), blobInfo.filename());
            fetch(uploadUrl, {
                method: 'POST',
                headers: { 'X-CSRFToken': getCsrfToken() },
                body: formData
            })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (data.location) success(data.location);
                else failure(data.error || 'Upload failed');
            })
            .catch(function (err) { failure('Upload failed: ' + err); });
        },
        file_picker_types: 'image',
        file_picker_callback: function (callback, value, meta) {
            if (meta.filetype === 'image') {
                var input = document.createElement('input');
                input.type = 'file';
                input.accept = 'image/*';
                input.onchange = function () {
                    var file = this.files[0];
                    var formData = new FormData();
                    formData.append('file', file);
                    fetch(uploadUrl, {
                        method: 'POST',
                        headers: { 'X-CSRFToken': getCsrfToken() },
                        body: formData
                    })
                    .then(function (r) { return r.json(); })
                    .then(function (data) {
                        if (data.location) callback(data.location, { alt: file.name });
                    });
                };
                input.click();
            }
        },
        setup(editor) {
            editor.on("SaveContent", function (event) {
                event.content = event.content
                    .replace(/&nbsp;/g, " ")
                    .replace(/\s{2,}/g, " ");
                return event.content;
            });

            if (media_manager_url && browseFiles) {
                editor.ui.registry.addButton("browse", {
                    title: "Insert files",
                    icon: "browse",
                    onAction: browseFiles
                });
            }
        }
    };

    return config;
};
