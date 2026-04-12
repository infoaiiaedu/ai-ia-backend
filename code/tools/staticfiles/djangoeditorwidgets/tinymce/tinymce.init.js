const media_manager_url = window.MEDIA_MANAGER_URL || "/admin/mmanager/";

var mm = null;
var browseFiles = null;

if (typeof MManager !== 'undefined') {
    mm = new MManager({ media_manager_url: media_manager_url });

    window.addEventListener("message", function (event) {
        mm.eventListener(event);
    });

    browseFiles = function (value, filetype, callback) {
        if (!mm.active) {
            mm.active = true;
            mm.callback = callback;
            mm.open();
        } else if (mm.win) {
            mm.win.focus();
        }
    };
}

var config = tinymceConfig({
    name: "default",
    media_manager_url: mm ? media_manager_url : null,
    media_upload_url: "/media/",
    images_upload_url: "/admin/tinymce-upload/",
    browseFiles: browseFiles
});

tinymce.init(config);
