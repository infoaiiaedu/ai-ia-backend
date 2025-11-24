class MManager {
    constructor({
        media_manager_url,
        width = 1000,
        height = 640,
        active = false,
        autoclose = true,
    }) {
        this.self_url = window.location.protocol + "//" + window.location.host;
        this.media_manager_url = media_manager_url;

        this.active = active;
        this.width = width;
        this.height = height;

        this.win = null;
        this.callback = null;
        this.autoclose = autoclose;

        this._connected = false;

        this.url = [
            this.media_manager_url,
            `?opener_origin=${this.self_url}`,
        ].join("");
    }

    open() {
        this.active = true;
        this.win = window.open(
            this.url,
            "Media Manager",
            `width=${this.width},height=${this.height}`
        );
    }

    close() {
        this.active = false;
        if (this.win) this.win.close();
        this.win = null;
        this.callback = null;
    }

    get connected() {
        return this._connected;
    }

    set connected(val) {
        this._connected = val;
        if (!val) {
            this.win = null;
            this.callback = null;
        }
    }

    postMessage(data) {
        if (this.win) {
            this.win.postMessage(
                { action: "mediamanager", ...data },
                this.media_manager_url
            );
        }
    }

    insertFile(detail) {
        if (!this.connected) return false;

        if ("files" in detail) detail = detail.files[0];

        const url = ("/media/" + detail.path).replace("//", "/");

        if (this.callback) {
            this.callback(url, { alt: detail.name || "" });
            if (this.autoclose) this.close();
        }
    }

    eventListener(event) {
        if (!this.active) return false;

        const data = event.data;
        if (data.action !== "mediamanager") return false;

        if (data.msg === "connected") {
            this.connected = true;
        } else if (data.msg === "insert-file") {
            this.insertFile(data);
        } else if (data.msg === "closed") {
            this.connected = false;
            this.close();
        }
    }
}