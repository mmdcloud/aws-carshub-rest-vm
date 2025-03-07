resource "aws_db_instance" "db" {
  allocated_storage   = var.allocated_storage
  db_name             = var.db_name
  engine              = var.engine
  engine_version      = var.engine_version
  publicly_accessible = var.publicly_accessible
  multi_az            = var.multi_az
  instance_class      = var.instance_class
  username             = var.username
  password             = var.password
  parameter_group_name = var.parameter_group_name
  skip_final_snapshot  = var.skip_final_snapshot
}