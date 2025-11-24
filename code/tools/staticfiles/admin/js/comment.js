function changeStatus(event, id) {
    let data = new FormData();
    let csrftoken = document.querySelector('meta[name="csrftoken"]').content;

    let checkbox = event.target;

    data.append("csrfmiddlewaretoken", csrftoken);

    url = window.location.pathname + id + "/toggle_status/";

    axios({
        method: "POST",
        url,
        data,
    })
        .then((res) => {
            let data = res.data;
            vNotify.success({
                title: "კომენტარი #" + id,
                text: data.is_pub ? "გამოქვეყნებულია" : "გაუქმებულია",
                fadeInDuration: 300,
                fadeOutDuration: 1000,
            });
        })
        .catch((e) => {
            vNotify.error({
                title: "კომენტარი #" + id,
                text: e.response.data.error,
                fadeInDuration: 300,
                fadeOutDuration: 1000,
            });

            setTimeout(() => {
                checkbox.checked = !checkbox.checked;
            }, 500);
        });
}
