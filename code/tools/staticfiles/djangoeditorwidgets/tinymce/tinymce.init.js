const media_manager_url = window.MEDIA_MANAGER_URL;

const mm = new MManager({
    media_manager_url
});

window.addEventListener("message", function (event) {
    mm.eventListener(event);
});

function browseFiles(value, filetype, callback) {
    if (!mm.active) {
        mm.active = true;
        mm.callback = callback;
        mm.open();
    } else if (mm.win) {
        mm.win.focus();
    }
}

const config = tinymceConfig({
    name: "default",
    media_manager_url: media_manager_url,
    media_upload_url: "/media/",
    browseFiles
});

tinymce.init(config);
