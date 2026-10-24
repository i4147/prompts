inspect python files in connected GitHub repo, and
1.add type annotation to files
2.debug and fix any possible errors
3.. convert all concurrent.futures usage to multiprocessing.pool.apply_async with fixed 8 workers
4.in every file that defined a -w --workers, -j,--jobs cli args, remove that arg and add a constant MAX_WORKERS=8 after import section
5-detect and report unused and dead code
update files inplace and commit changes
add any other necessary optimizations needed
rename files by their functionality like rename_HTML_by_title.oy
for every file replace current module doc string with a proper prompt for an AI chatchat to produce that code
