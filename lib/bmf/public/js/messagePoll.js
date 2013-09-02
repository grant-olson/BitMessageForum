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
          var new_message_text = "<button type='button' class='close' data-dismiss='alert'>&times;</button><strong>" + data.new_messages + "</strong> new messages!";
          new_message_text += "<small>";
          data.new_folders.forEach(function(folder) {
            new_message_text += "<a href='/" + folder + "/'>" + folder + "</a>&nbsp;";
          });
          new_message_text += "</small>";
            
          if ($('#alert').length){
            $("#alert").html(new_message_text);
          } else {
            $("#messages").append("<div class='alert alert-success' id='alert'>" + new_message_text);
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