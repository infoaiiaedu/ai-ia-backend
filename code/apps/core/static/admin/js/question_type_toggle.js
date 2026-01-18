(function($){
    function getInlineRoot($el){
        // Prefer the standard inline container
        var $inline = $el.closest('.inline-related');
        if($inline.length) return $inline;
        // Fallback: dynamic formset row with id pattern
        var $dynamic = $el.closest('[id^="question_set-"]');
        if($dynamic.length) return $dynamic;
        // Final fallback: nearest .form-row
        return $el.closest('.form-row');
    }

    function findFieldRow($root, fieldName){
        // Try to find the form-row wrapper for the given field inside the inline root
        var selector = "[name$='-" + fieldName + "']";
        var $field = $root.find(selector);
        if($field.length) {
            var $row = $field.closest('.form-row');
            if($row.length) return $row;
            return $field;
        }
        // As a fallback, try global selector
        var $global = $(selector);
        if($global.length) return $global.closest('.form-row');
        return $();
    }

    function toggleForSelect($select){
        var val = $select.val();
        var $root = getInlineRoot($select);

        var $correctRow = findFieldRow($root, 'correct_text_answer');
        var $answersGroup = null;

        // If on Question change page, answers are in answer_set-group
        if($('#answer_set-group').length && getInlineRoot($select).length === 0){
            $answersGroup = $('#answer_set-group');
        } else {
            // try to find an answers group inside this inline (if present)
            $answersGroup = $root.find('[id$="-answer_set-group"]');
            if(!$answersGroup.length) $answersGroup = $();
        }

        // Show/hide based on type
        if(val === 'mcq'){
            if($correctRow.length) $correctRow.hide();
            if($answersGroup && $answersGroup.length) $answersGroup.show();
        } else if(val === 'open'){
            if($correctRow.length) $correctRow.show();
            if($answersGroup && $answersGroup.length) $answersGroup.hide();
        } else {
            if($correctRow.length) $correctRow.hide();
            if($answersGroup && $answersGroup.length) $answersGroup.hide();
        }
    }

    function initToggle(){
        var selector = "select[name$='-question_type'], select#id_question_type, select[name='question_type']";

        // Bind change handler
        $(document).on('change', selector, function(){
            toggleForSelect($(this));
        });

        // Initialize existing selects
        $(selector).each(function(){
            toggleForSelect($(this));
        });

        // When a new inline is added, initialize that inline's selects
        $(document).on('click', '.add-row a, .add-another', function(){
            setTimeout(function(){
                $(selector).each(function(){
                    toggleForSelect($(this));
                });
            }, 300);
        });
    }

    $(document).ready(function(){
        initToggle();
    });
})(django && django.jQuery ? django.jQuery : jQuery);
