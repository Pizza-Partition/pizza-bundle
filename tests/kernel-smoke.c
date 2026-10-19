#define _GNU_SOURCE
#include <errno.h>
#include <stdlib.h>
#include <sys/mount.h>
#include <sys/syscall.h>
#include <sys/wait.h>
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
    mkdir("/proc", 0755);
    if (mount("proc", "/proc", "proc", 0, NULL) != 0) goto failed;
    FILE *modules = fopen("/etc/pizza/modules", "r");
    if (!modules) goto failed;
    char line[4096];
    unsigned count = 0;
    while (fgets(line, sizeof line, modules)) {
      line[strcspn(line, "\n")] = 0;
      int fd = open(line, O_RDONLY);
      if (fd < 0) goto failed;
      int result = syscall(SYS_finit_module, fd, "", 0);
      close(fd);
      if (result < 0 && errno != EEXIST) goto failed;
      count++;
    }
    if (ferror(modules) || !count) goto failed;
    fclose(modules);
    if (chdir("/opt/pizza/bundle") != 0) goto failed;
    pid_t child = fork();
    if (child == 0) {
      execl("bin/pizza-abi-check", "pizza-abi-check", "libWPEWebKit-2.0.so.1", (char *)NULL);
      _exit(127);
    }
    int status;
    if (child < 0 || waitpid(child, &status, 0) != child || !WIFEXITED(status) || WEXITSTATUS(status)) goto failed;
    printf("PIZZA_BASE_MODULES:%u\nPIZZA_BASE_READY:%s\n", count, info.release);
  } else {
    puts("PIZZA_KERNEL_MISMATCH");
  }
  goto done;
failed:
  puts("PIZZA_BASE_FAILED");
done:
  fflush(stdout);
  sync();
  reboot(LINUX_REBOOT_CMD_POWER_OFF);
  for (;;)
    pause();
}
