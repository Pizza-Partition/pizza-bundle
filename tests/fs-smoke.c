#include <blockdev/blockdev.h>
#include <blockdev/fs.h>
#include <stdio.h>

#define FULL (BD_FS_TECH_MODE_MKFS | BD_FS_TECH_MODE_WIPE | BD_FS_TECH_MODE_CHECK | BD_FS_TECH_MODE_REPAIR | BD_FS_TECH_MODE_SET_LABEL | BD_FS_TECH_MODE_QUERY | BD_FS_TECH_MODE_RESIZE | BD_FS_TECH_MODE_SET_UUID)

int main(void) {
  GError *error = NULL;
  BDPluginSpec fs = { BD_PLUGIN_FS, "libbd_fs.so.3" };
  BDPluginSpec *plugins[] = { &fs, NULL };
  if (!bd_init(plugins, NULL, &error)) {
    fprintf(stderr, "Filesystem plugin: %s\n", error ? error->message : "unavailable");
    return 1;
  }
  const struct { BDFSTech tech; const char *name; guint64 mode; } checks[] = {
    {BD_FS_TECH_BTRFS, "btrfs", FULL},
    {BD_FS_TECH_EXT2, "ext2", FULL},
    {BD_FS_TECH_EXT3, "ext3", FULL},
    {BD_FS_TECH_EXT4, "ext4", FULL},
    {BD_FS_TECH_XFS, "xfs", FULL},
    {BD_FS_TECH_VFAT, "vfat", FULL},
    {BD_FS_TECH_NTFS, "ntfs", FULL},
    {BD_FS_TECH_EXFAT, "exfat", BD_FS_TECH_MODE_MKFS | BD_FS_TECH_MODE_CHECK | BD_FS_TECH_MODE_REPAIR | BD_FS_TECH_MODE_QUERY | BD_FS_TECH_MODE_SET_LABEL | BD_FS_TECH_MODE_SET_UUID},
    {BD_FS_TECH_F2FS, "f2fs", BD_FS_TECH_MODE_MKFS | BD_FS_TECH_MODE_CHECK | BD_FS_TECH_MODE_REPAIR | BD_FS_TECH_MODE_QUERY | BD_FS_TECH_MODE_RESIZE},
    {BD_FS_TECH_NILFS2, "nilfs2", BD_FS_TECH_MODE_MKFS | BD_FS_TECH_MODE_QUERY | BD_FS_TECH_MODE_RESIZE | BD_FS_TECH_MODE_SET_LABEL | BD_FS_TECH_MODE_SET_UUID},
    {BD_FS_TECH_UDF, "udf", BD_FS_TECH_MODE_MKFS | BD_FS_TECH_MODE_QUERY | BD_FS_TECH_MODE_SET_LABEL | BD_FS_TECH_MODE_SET_UUID},
  };
  for (unsigned i = 0; i < sizeof checks / sizeof checks[0]; i++) {
    if (!bd_fs_is_tech_avail(checks[i].tech, checks[i].mode, &error)) {
      fprintf(stderr, "%s dependencies: %s\n", checks[i].name, error ? error->message : "unavailable");
      return 2;
    }
  }
  puts("PIZZA_LIBBLOCKDEV_FS_READY:11");
  return 0;
}
