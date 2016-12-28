/* Function to allow the projects to show up as a tree */

function toggleOddEven() {
  var isEven = false;

  $('table.list tr.project:not(.hide)').each(function() {
    var e = $(this);
    e.removeClass('odd');
    e.removeClass('even');
    e.addClass(isEven ? 'even' : 'odd');
    isEven = !isEven;
  })
}

function expandProjectTree(id) {
  $('table.list tr.child.' + id).each(function() {
    var e = $(this);
    e.removeClass('hide');
    if (e.hasClass('open')) {
      expandProjectTree(e.context.id);
    }
  })
}

function collapseProjectTree(id) {
  $('table.list tr.child.' + id).each(function() {
    var e = $(this);
    e.addClass('hide');
    collapseProjectTree(e.context.id);
  })
}

function toggleShowHide(id) {
  var e = $('#' + id);

  if (e.hasClass('open')) {
    collapseProjectTree(id);
    e.removeClass('open');
  } else {
    expandProjectTree(id);
    e.addClass('open');
  }

  toggleOddEven();
}

function expandAll() {
  $('table.list tr.project').each(function() {
    var e = $(this);
    e.removeClass('hide');
    if (!e.hasClass('leaf')) {
      e.addClass('open');
    }
  });

  toggleOddEven();
}

function collapseAll() {
  $('table.list tr.project').each(function() {
    var e = $(this);
    e.removeClass('open');
    if (!e.hasClass('root')) {
      e.addClass('hide');
    }
  });

  toggleOddEven();
}
