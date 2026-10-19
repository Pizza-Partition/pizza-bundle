#include <fcntl.h>
#include <linux/reboot.h>
#include <stdio.h>
#include <string.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/utsname.h>
#include <unistd.h>

int main(void) {
  mkdir("/dev", 0755);
  mknod("/dev/console", S_IFCHR | 0600, makedev(5, 1));
  int console = open("/dev/console", O_RDWR);
  if (console >= 0)
    for (int fd = 0; fd < 3; fd++)
      dup2(console, fd);
  struct utsname info;
  if (uname(&info) == 0 && !strcmp(info.release, EXPECTED_KERNEL)) {
    printf("PIZZA_KERNEL_READY:%s\n", info.release);
  } else {
    puts("PIZZA_KERNEL_MISMATCH");
  }
  fflush(stdout);
  sync();
  reboot(LINUX_REBOOT_CMD_POWER_OFF);
  for (;;)
    pause();
}
