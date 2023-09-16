class Comment{
  String uid;
  String email;
  DateTime date;
  String comment;
  String commentId;
  Comment({this.uid, this.email, this.date, this.comment});
}



class CommentNotification{
  String qID;
  String lastCommentedUID;
  String lastCommentedEmail;
  String lastCommentedDate;

  CommentNotification({this.qID, this.lastCommentedUID, this.lastCommentedEmail, this.lastCommentedDate});
}