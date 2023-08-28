# TODO: remove in favor of Tailscale SSH

resource "aws_key_pair" "mmazzanti" {
  key_name   = "mmazzanti"
  public_key = file("${path.module}/keys/mmazzanti.pub")
}

resource "aws_key_pair" "nikitawootten" {
  key_name   = "nikitawootten"
  public_key = file("${path.module}/keys/nikitawootten.pub")
}
