$(function() {

  $("form.delete_conversation").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure you want to delete this conversation? All the messsages will be lost for both users!");
    if (ok) {
      this.submit();
    }
  });

  $("form.delete_board_message").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure you want to delete this board message?");
    if (ok) {
      this.submit();
    }
  });

  $("form.delete_board").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure you want to delete this board? All the messages will be lost!");
    if (ok) {
      this.submit();
    }
  });

  $("form.delete_account").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure you want to delete your account? All your private messages will be deleted, but the boards you created will remain for 24 hours.");
    if (ok) {
      this.submit();
    }
  });

});
