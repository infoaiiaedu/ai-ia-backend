const $ = django.jQuery;

$.fn.djangoAdminSelect2 = function () {
    $.each(this, function (i, element) {
        $(element).select2({
            ajax: {
                headers: {
                    "X-Referer": window.location.href,
                },
                data: (params) => {
                    let element_id = this.id;
                    const allvars = Array.from(
                        document.querySelectorAll(".admin-autocomplete")
                    ).reduce((r, e) => {
                        if (e.id != element_id) {
                            r[e.id] = e.value;
                        }
                        return r;
                    }, {});

                    return {
                        term: params.term,
                        page: params.page,
                        app_label: element.dataset.appLabel,
                        model_name: element.dataset.modelName,
                        field_name: element.dataset.fieldName,
                        ...allvars,
                        element_id: element_id,
                    };
                },
            },
        });
    });
    return this;
};

$(function () {
    $(".admin-autocomplete").not("[name*=__prefix__]").djangoAdminSelect2();

    // let currentCategory = $("#id_category").val();

    // $("#id_category").on("change", function () {
    //     let newCategory = $(this).val();
    //     if (currentCategory != newCategory) {
    //         $("#id_category").val(null).trigger("change");
    //         currentCategory = newCategory;
    //         // Trigger AJAX refresh here if needed, or ensure the category_id is being passed
    //     }
    // });

    document.addEventListener("formset:added", (event) => {
        $(event.target).find(".admin-autocomplete").djangoAdminSelect2();
    });
});
