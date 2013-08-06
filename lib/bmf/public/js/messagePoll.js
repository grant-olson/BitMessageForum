function pollServer(){

  setInterval(function(){
    $.ajax({
      type: 'GET', 
      dataType: 'json',
      url: '/json/new_messages/',
      cache: false,
      success: function(data){
        //console.log(data.new_messages);
        if (data.new_messages > 0) {
          if ($('#alert').length){
            $("#alert").html("<button type='button' class='close' data-dismiss='alert'>&times;</button><strong>" + data.new_messages + "</strong> new messages!");
          } else {
            $("#messages").append("<div class='alert alert-success' id='alert'><button type='button' class='close' data-dismiss='alert'>&times;</button><strong>" + data.new_messages + "</strong> new messages!</div>");
          }
        }
      }
    });
  }, 4000);
};

$('#select-all').click(function(event) {   
    if(this.checked) {
        // Iterate each checkbox
        $(':checkbox').each(function() {
            this.checked = true;                        
        });
    } else {
      // Iterate each checkbox 
      $(":checkbox").each(function() {
        this.checked = false;
      });
    } 
});

$(document).ready(function(){
  pollServer();
});