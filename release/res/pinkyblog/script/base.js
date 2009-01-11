/*
	Pinky:blog base-script
	License: NYSL 0.9982 (http://www.kmonos.net/nysl/)
*/


CAPTIONS = {
	show_detail: '詳細表示',
	hide_detail: '隠す'
};

$(document).ready(function(){
	if(!document.getElementById){
		/* DOM未対応ブラウザでは無効 */
	} else {
		/* TextAreaResizer */
		textarea = $('textarea:not(.processed)');
		textarea.css('margin-bottom', '0');
		textarea.TextAreaResizer();
		
		
		/* チェックボックス選択補助 */
		$('#SelectingTool').html('<a href="#PAGETOP" onclick="return check_all();">すべて選択</a>　<a href="#PAGETOP" onclick="return uncheck_all();">すべて選択解除</a>　<a href="#PAGETOP" onclick="return switch_all();">選択反転</a>');
		
		/* 詳細表示スイッチ */
		$('.pinky-detail-switch').text(CAPTIONS.show_detail);
	}
});



/* from http://amix.dk/blog/viewEntry/161 */
function RND(tmpl, ns) {
  var fn = function(w, g) {
    g = g.split("|");
    var cnt = ns[g[0]];
    for(var i=1; i < g.length; i++)
      cnt = eval(g[i])(cnt);
    return cnt || w;
  };
  return tmpl.replace(/%(([A-Za-z0-9_|.]))/g, fn);
}

function check_all(){
	$("input[type='checkbox']").attr('checked', 'checked');
	return false;
}

function uncheck_all(){
	$("input[type='checkbox']").removeAttr('checked', 'checked');
	return false;
}

function switch_all(){
	var checked = $("input[type='checkbox'][checked]");
	var unchecked = $("input[type='checkbox']:not([checked])");

	unchecked.attr('checked', 'checked');
	checked.removeAttr('checked', 'checked');
	return false;
}

function toggle_detail_entry(a, target, data){
	/* 要素構築 */
	target.empty();
	target.append('<td></td>');
	target.append('<td colspan="10"><dl></dl></td>');
	var dl = target.find('dl');
	$.each(data, function(key, val){
		dl.append('<dt>' + key + '</dt><dd>' + val + '</dd>');
	});
	
	/* 表示 */
	target.toggle();
	
	/* リンクキャプション変更 */
	if(target.filter(':visible')[0]){
		a.text(CAPTIONS.hide_detail);
	} else {
		a.text(CAPTIONS.show_detail);
	};

}





/*
function edit_comment(a, uri, number){

	comment = $('#COMMENT-' + number.toString());
	edit_form_id = 'COMMENT-' + number.toString() + '-EDIT-FORM'
	if($('#' + edit_form_id).size() == 0){
		comment.after('<div id="' + edit_form_id + '"></div>');
	};
		
	target = comment.next();
	target.html('Loading...');
	$.get(uri, function(data, status){
		if(status == 'success'){
			$(a).hide();
			kizi = $(data).find('#KIZI');
			kizi.find('.modori').remove();
			target.html(kizi.html());
		} else {
			target.html('<em>コメントフォームの読み込みに失敗しました。</em>');
		}
	});
	return false;
};
*/