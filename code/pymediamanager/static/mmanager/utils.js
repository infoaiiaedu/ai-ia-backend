const queryString = {
    load(query) {
        return query
            .slice(1)
            .split("&")
            .map((e) => e.split("="))
            .reduce((m, [key, val]) => {
                if (/^\d+$/.test(val)) {
                    val = parseInt(val);
                }

                if (key in m) {
                    if (Array.isArray(m[key])) {
                        m[key].push(val);
                    } else {
                        m[key] = [m[key], val];
                    }
                } else {
                    m[key] = val;
                }
                return m;
            }, {});
    },
    dump(query) {
        return (
            "?" +
            Object.entries(query)
                .map(([key, val]) => {
                    if (!Array.isArray(val)) {
                        return `${key}=${val}`;
                    } else {
                        return val.map((v) => `${key}=${v}`).join("&");
                    }
                })
                .join("&")
        );
    },
};

let query = queryString.load(window.location.search);
const origin = query.opener_origin;
const is_opened = !!(window.opener && origin);

function postMessage(data) {
    is_opened &&
        window.opener.postMessage(
            {
                action: "mediamanager",
                ...data,
            },
            origin
        );
}

if (is_opened) {
    postMessage({
        msg: "connected",
    });

    window.addEventListener("message", function (event) {
        let data = event.data;

        if (data.action !== "mediamanager") {
            return false;
        }
    });
}

window.addEventListener("beforeunload", function () {
    postMessage({
        msg: "closed",
    });
});
