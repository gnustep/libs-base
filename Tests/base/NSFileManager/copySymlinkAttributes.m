#import "Testing.h"
#import <Foundation/Foundation.h>

#if defined(_WIN32)

int main()
{
  START_SET("copySymlinkAttributes")
  SKIP("POSIX symbolic links are not available on this platform")
  END_SET("copySymlinkAttributes")
  return 0;
}

#else

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

/* Copying or linking a tree that contains symbolic links must apply the
 * attributes of each link to the new link itself (or not at all), never
 * to the file the link points to.
 */

static struct stat
statOf(NSString *path)
{
  struct stat	sb;

  memset(&sb, 0, sizeof(sb));
  stat([path fileSystemRepresentation], &sb);
  return sb;
}

static BOOL
sameAttributes(struct stat a, struct stat b)
{
  return (a.st_mode == b.st_mode && a.st_uid == b.st_uid
    && a.st_gid == b.st_gid && a.st_mtime == b.st_mtime);
}

static NSString *
linkContent(NSString *path)
{
  return [[NSFileManager defaultManager]
    pathContentOfSymbolicLinkAtPath: path];
}

static void
resetFile(NSString *path)
{
  struct timeval	tv[2];

  chmod([path fileSystemRepresentation], 0644);
  tv[0].tv_sec = tv[1].tv_sec = 978307200;
  tv[0].tv_usec = tv[1].tv_usec = 0;
  utimes([path fileSystemRepresentation], tv);
}

static void
makeFile(NSString *path)
{
  [[NSFileManager defaultManager] createFileAtPath: path
    contents: [NSData dataWithBytes: "x" length: 1] attributes: nil];
  resetFile(path);
}

int main()
{
  ENTER_POOL
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSString		*root;
  NSString		*src;
  NSString		*outside;
  NSString		*file;
  NSString		*dst;
  struct stat		outsideBefore;
  struct stat		fileBefore;
  NSError		*err = nil;

  root = [[mgr currentDirectoryPath]
    stringByAppendingPathComponent: @"SymlinkAttributesTestDir"];
  [mgr removeFileAtPath: root handler: nil];
  [mgr createDirectoryAtPath: root attributes: nil];
  src = [root stringByAppendingPathComponent: @"src"];
  [mgr createDirectoryAtPath: src attributes: nil];
  outside = [root stringByAppendingPathComponent: @"outside"];
  file = [src stringByAppendingPathComponent: @"file"];
  makeFile(outside);
  makeFile(file);
  [mgr createSymbolicLinkAtPath: [src stringByAppendingPathComponent: @"rel"]
		    pathContent: @"file"];
  [mgr createSymbolicLinkAtPath: [src stringByAppendingPathComponent: @"abs"]
		    pathContent: outside];
  [mgr createSymbolicLinkAtPath: [root stringByAppendingPathComponent: @"top"]
		    pathContent: outside];
  outsideBefore = statOf(outside);
  fileBefore = statOf(file);
  PASS((outsideBefore.st_mode & 07777) == 0644
    && (fileBefore.st_mode & 07777) == 0644
    && outsideBefore.st_mtime == 978307200,
    "test files are set up with mode 0644 and an old modification date")

  dst = [root stringByAppendingPathComponent: @"copy1"];
  PASS([mgr copyPath: src toPath: dst handler: nil],
    "-copyPath:toPath:handler: copies a directory with symbolic links")
  PASS(sameAttributes(statOf(outside), outsideBefore),
    "-copyPath:toPath:handler: leaves the target of an absolute link alone")
  PASS(sameAttributes(statOf(file), fileBefore),
    "-copyPath:toPath:handler: leaves the source file alone")
  PASS((statOf([dst stringByAppendingPathComponent: @"file"]).st_mode & 07777)
    == 0644, "-copyPath:toPath:handler: keeps the mode of the copied file")
  PASS_EQUAL(linkContent([dst stringByAppendingPathComponent: @"abs"]),
    outside, "the copied absolute link points where the original did")
  PASS_EQUAL(linkContent([dst stringByAppendingPathComponent: @"rel"]),
    @"file", "the copied relative link points where the original did")

  resetFile(outside);
  resetFile(file);
  dst = [root stringByAppendingPathComponent: @"copy2"];
  PASS([mgr copyItemAtPath: src toPath: dst error: &err],
    "-copyItemAtPath:toPath:error: copies a directory with symbolic links")
  PASS(sameAttributes(statOf(outside), outsideBefore),
    "-copyItemAtPath:toPath:error: leaves the target of an absolute link"
    " alone")
  PASS((statOf([dst stringByAppendingPathComponent: @"file"]).st_mode & 07777)
    == 0644, "-copyItemAtPath:toPath:error: keeps the mode of the copied file")

  resetFile(outside);
  resetFile(file);
  dst = [root stringByAppendingPathComponent: @"copy3"];
  PASS([mgr copyPath: [root stringByAppendingPathComponent: @"top"]
	      toPath: dst handler: nil],
    "-copyPath:toPath:handler: copies a symbolic link")
  PASS(sameAttributes(statOf(outside), outsideBefore),
    "copying a symbolic link leaves its target alone")
  PASS_EQUAL(linkContent(dst), outside,
    "the copied link points where the original did")

  START_SET("-linkPath:toPath:handler:")
  dst = [root stringByAppendingPathComponent: @"hardlink"];
  if (link([file fileSystemRepresentation],
    [dst fileSystemRepresentation]) != 0)
    {
      SKIP("hard links are not supported here")
    }
  resetFile(outside);
  resetFile(file);
  dst = [root stringByAppendingPathComponent: @"link1"];
  PASS([mgr linkPath: src toPath: dst handler: nil],
    "-linkPath:toPath:handler: links a directory with symbolic links")
  PASS(sameAttributes(statOf(outside), outsideBefore),
    "-linkPath:toPath:handler: leaves the target of an absolute link alone")
  PASS_EQUAL(linkContent([dst stringByAppendingPathComponent: @"abs"]),
    outside, "the linked tree's absolute link points where the original did")
  END_SET("-linkPath:toPath:handler:")

  [mgr removeFileAtPath: root handler: nil];
  LEAVE_POOL
  return 0;
}

#endif
