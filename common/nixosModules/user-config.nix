{ pkgs, ... }:
{
  users.users.hacdc = {
    isNormalUser  = true;
    extraGroups  = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [
    neovim-unwrapped # Unwrapped, to avoid pulling in ruby/python dependencies
    jq
  ];
}