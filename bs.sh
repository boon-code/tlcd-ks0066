#!/bin/sh
python -c"import sys;sys.argv[0] = '$0';sys.path.insert(0, '$0');import npyck;npyck.load_pack('bs', '$0', use_globals=True)" $*
exit

PK     �U�<id�y�	  �	     bsdef.pyimport sys
import os
import types
import optparse
import bsfile
import bssettings

class CollectException(Exception):
    pass


class NoBasicTypeException(CollectException):
    pass


def collect_defines(directory):
    
    config = {}
    cache_file = os.path.join(directory, bssettings.CFG_CACHEFILE)
    usr_file = os.path.join(directory, bssettings.CFG_USERFILE)
    
    if ((not os.path.isfile(cache_file))
            or (not os.path.isfile(usr_file))):
        # error msg please
        return config
    else:
        config = bsfile.load_cfg(cache_file)
        ucfg = bsfile.load_cfg(usr_file)
        config.update(ucfg)
        
        return config


def prepare_define(value):
    
    if isinstance(value, types.StringTypes):
        return value
    elif isinstance(value, types.BooleanType):
        return '1' if value else '0'
    elif (isinstance(value, types.IntType) or 
            isinstance(value, types.LongType) or
            isinstance(value, types.FloatType)):
        return str(value)
    else:
        raise NoBasicTypeException


def output_define(key, value, all=False):
    
    try:
        dvalue = prepare_define(value)
        print '-D"%s=%s"' % (key, dvalue),
    except NoBasicTypeException:
        if all:
            if (isinstance(value, types.TupleType) or 
                    isinstance(value, types.ListType)):
                for (index, v) in enumerate(value):
                    output_define(key + "_%d" % index, v, all=all)
            elif isinstance(value, types.DictType):
                
                for (k, v) in value.iteritems():
                    strkey = str(k)
                    output_defines(key + strkey, v, all=all)


def main(args):
    
    parser = optparse.OptionParser(
        usage="usage: %prog def [options] path")
    
    parser.add_option("-v", "--verbose", action="store_true",
        help="turns on warnings (to stderr)...")
    
    parser.add_option("-a", "--all", action="store_true",
        help="shows all defines (even dictonaries or python stuff)")
    
    parser.set_defaults(verbose=False, all=False)
    
    options, args = parser.parse_args(args)
    
    if len(args) < 2:
        parser.print_help(file=sys.stderr)
        sys.exit(1)
    else:
        if os.path.isdir(args[1]):
            path = args[1]
        else:
            path = os.path.split(args[1])[0]
    
    config = collect_defines(path)
    
    for (dkey, value) in config.iteritems():
        output_define(dkey, value, all=options.all)
PK     ��<�l�g  g  	   bseval.pyimport sys
import os
import optparse
import bssettings
import traceback
import bsdef
import math

def cpp_escape(value):
    value = value.replace('\\', '\\\\')
    value = value.replace('"', '\\"')
    return value


def eval_data(code, env):
    
    try:
        exec(code, env, env)
    except (KeyboardInterrupt, SystemExit):
        sys.exit()
    except Exception:
        sys.stderr.write(traceback.format_exc())
        sys.exit(1)


class EchoHelper(object):
    
    def __init__(self, dst):
        self._dst = dst
    
    def _list_echo(self, text, pre=None, post=None):
        if not (pre is None):
            self._dst.write(str(pre))
        if len(text) > 0:
            for element in text:
                self._dst.write(str(element))
        if not (post is None):
            self._dst.write(str(post))
        self._dst.flush()
    
    def echo(self, *text):
        self._list_echo(text)
    
    def echo_nl(self, *text):
        self._list_echo(text, post='\n')
    
    def str_echo(self, *text):
        text = [cpp_escape(str(i)) for i in text]
        self._list_echo(text, pre='"', post='"')
    
    def str_echo_nl(self, *text):
        text = [cpp_escape(str(i)) for i in text]
        self._list_echo(text, pre='"', post='"\n')


def parse_data(data, dst, env):
    
    echo_obj = EchoHelper(dst)
    env['echo'] = echo_obj.echo
    env['put'] = echo_obj.echo_nl
    env['sput'] = echo_obj.str_echo_nl
    env['secho'] = echo_obj.str_echo
    
    tag = False
    code = ''
    found = True
    
    while found:
        if not tag:
            start_pos = data.find(bssettings.START_TAG)
            if start_pos >= 0:
                if len(data[0:start_pos]) > 0:
                    dst.write(data[0:start_pos])
                tag = True
                data = data[start_pos:]
                code_match = bssettings.CODE_RE.search(data)
                if not (code_match is None):
                    code = ''
                    data = data[code_match.end():]
            else:
                found = False
        
        if tag:
            end_pos = data.find(bssettings.END_TAG)
            if end_pos >= 0:
                tag = False
                if not (code_match is None):
                    code = data[0:end_pos]
                    eval_data(code, env)
                    end_pos += len(bssettings.END_TAG)
                    data = data[end_pos:]
                else:
                    sys.stderr.write("unknown tag...")
            else:
                found = False
                sys.stderr.write("didn't find '?>'")
                sys.exit()
    
    if len(data) > 0:
        dst.write(data)
        dst.flush()

def main(args):
    
    parser = optparse.OptionParser(
        usage="usage: %prog eval [options] file [other files]")
    
    parser.add_option("-o", "--output",
        help="writes output to file 'output'")
    
    parser.add_option("-a", "--auto-output", action="store_true",
        dest="auto", help="automatically outputs bla.xy.in to bla.xy")
    
    parser.add_option("-v", "--verbose", action="store_true",
        help="turns on warnings (to stderr)...")
    
    parser.set_defaults(verbose=False, auto=False)
    
    options, args = parser.parse_args(args)
    
    if len(args) < 2:
        sys.exit(1)
    elif options.output and options.auto:
        sys.stderr.write("you can't set auto and define an output\n")
        sys.stderr.flush()
        sys.exit(1)
    else:
        args = args[1:]
        if options.output:
            if len(args) > 1 and options.verbose:
                sys.stderr.write("since output is set, only the first" +
                    "file will be processed\n")
                sys.stderr.flush()
            args = [args[0]]
    
    for i in args:
        f = open(i, 'r')
        try:
            data = f.read()
        finally:
            f.close()
        
        config = bsdef.collect_defines(os.path.split(i)[0])
                
        nenv = {'__builtins__' : __builtins__,
            'BS_VERSION' : bssettings.VERSION,
            'math' : math, 'cfg' : config}
        
        env = {}
        env.update(config)
        env.update(nenv)
        
        if options.output:
            dst = open(options.output, 'w')
            try:
                parse_data(data, dst, env)
            finally:
                dst.close()
        elif options.auto:
            if i.endswith('.in'):
                dst = open(i.rstrip('.in'), 'w')
                try:
                    parse_data(data, dst, env)
                finally:
                    dst.close()
            else:
                dst = open(i + ".pev", 'w')
                try:
                    parse_data(data, dst, env)
                finally:
                    dst.close()
        else:
            dst = sys.stdout
            try:
                parse_data(data, dst, env)
            finally:
                dst.close()

PK     �]�<P�Ծ'  '  
   bscuser.pyimport sys
import os
import math
import copy
import cPickle
import Queue
import bssettings

def shell_escape(value):
    value = value.replace('\\', '\\\\')
    value = value.replace('"', '\\"')
    value = value.replace('$', '\$')
    return value


class UserConfigException(Exception):
    pass


class MissingEntryError(UserConfigException):
    pass


class SkipException(UserConfigException):
    pass


class ValueCheckException(UserConfigException):
    pass


class UnimplementedException(UserConfigException):
    pass


class CyclingDepencyError(UserConfigException):
    pass


class WasNotAskedError(UserConfigException):
    pass


class BasicInput(object):
    
    def __init__(self, name, value, options):
        
        self._dict = {'name' : name, 'old' : value, 'value' : None}
        self._quest = options['question'] % self._dict
        self._old = options['old'] % self._dict
        self._asked = False
        if 'help' in options:
            self._help = options['help'] % self._dict
        else:
            self._help = None
        
        self.__opts = options
    
    def _real_ask(self, reconfigure):
        raise UnimplementedException()
    
    def _check_depency(self, in_obj):
        pass
    
    def _ask(self, reconfigure):
        
        if self._asked:
            value = self._dict['value']
        else:
            value = self._dict['old']
            
            if (value is None) or reconfigure:
                value = self._real_ask(reconfigure)
                
                # let's think about this...
                #if isinstance(value, BasicInput):
                #    value = value._ask()
            else:
                value = self._dict['old']
            
            self._dict['value'] = value
            self._asked = True
        
        if "check" in self.__opts:
            try:
                result = self.__opts['check'](value)
                if not result:
                    raise ValueCheckException()
            except TypeError:
                print "something wrong with check funtion..."
                print "ignoring..."
        
        return value
    
    def _eval(self, module, reconfigure):
        
        value = self._ask(reconfigure)
        module.add_cfg(self._dict['name'], value, True)
    
    def read(self):
        
        if self._asked:
            return self._dict['value']
        else:
            raise WasNotAskedError()


class UserExprInput(BasicInput):
    
    def __init__(self, name, value, options):
        
        if not ('question' in options):
            options['question'] = "Enter Expression for %(name)s"
        if not ('old' in options):
            options['old'] = "To Keep old value '%(old)s' press Ctrl+D"
        
        BasicInput.__init__(self, name, value, options)
    
    def _real_ask(self, reconfigure):
        
        print self._quest
        if reconfigure:
            print self._old
        if self._help:
            print self._help
        try:
            value = raw_input()
            try:
                value = eval(value, {'__builtins__' : __builtins__,
                    'math' : math})
            except Exception:
                print "couldn't use as expression"
                value = shell_escape(value)
            
            print "configuring: %s = %s" % (self._dict['name'], value)
            return value
        except EOFError:
            if reconfigure:
                print "keep old value: %(name)s = %(old)s" % self._dict
                return self._dict['old']
            else:
                raise SkipException()


class UserDefInput(BasicInput):
    
    def __init__(self, name, value, options):
        
        if not ('question' in options):
            options['question'] = "Enter Expression for %(name)s"
        if not ('old' in options):
            options['old'] = "To Keep old value '%(old)s' press Ctrl+D"
        
        BasicInput.__init__(self, name, value, options)
    
    def _real_ask(self, reconfigure):
        
        print self._quest
        if reconfigure:
            print self._old
        if self._help:
            print self._help
        try:
            value = shell_escape(raw_input())
            
            print "configuring: %s = %s" % (self._dict['name'], value)
            return value
        except EOFError:
            if reconfigure:
                print "keep old value: %(name)s = %(old)s" % self._dict
                return self._dict['old']
            else:
                raise SkipException()


class UserStringInput(BasicInput):
    
    def __init__(self, name, value, options):
        
        if not ('question' in options):
            options['question'] = "Enter String for %(name)s"
        if not ('old' in options):
            options['old'] = "To Keep old value '%(old)s' press Ctrl+D"
        
        BasicInput.__init__(self, name, value, options)
    
    def _real_ask(self, reconfigure):
        
        print self._quest
        if reconfigure:
            print self._old
        if self._help:
            print self._help
        try:
            value = shell_escape('"%s"' % raw_input())
            print "configuring: %s = %s" % (self._dict['name'], value)
            return value
        except EOFError:
            if reconfigure:
                print "keep old value: %(name)s = %(old)s" % self._dict
                return self._dict['old']
            else:
                raise SkipException()


class UserListInput(BasicInput):
    
    def __init__(self, name, value, darray, options):
        
        if not ('question' in options):
            options['question'] = "Choose var %(name)s from list:"
        if not ('old' in options):
            options['old'] = "To Keep old value '%(old)s' press Ctrl+D"
        
        self._remove = False
        if 'remove' in options:
            if options['remove']:
                self._remove = True
        
        BasicInput.__init__(self, name, value, options)
        self._darray = darray
    
    def _real_ask(self, reconfigure):
        
        for (i,v) in enumerate(self._darray):
            print "%d %s" % (i, v)
        print self._quest
        if reconfigure:
            print self._old
        if self._help:
            print self._help
        try:
            number = raw_input()
            return self._darray[int(number)]
        except (IndexError, ValueError, KeyError):
            print "invalid choice"
            return self._real_ask(reconfigure)
        except EOFError:
            if reconfigure:
                print "keep old value: %(name)s = %(old)s" % self._dict
                return self._dict['old']
            else:
                raise SkipException()
    
    def _ask(self, reconfigure):
        
        ret = BasicInput._ask(self, reconfigure)
        
        if self._remove:
            if ret in self._darray:
                self._darray.remove(ret)
        return ret


class SimpleCallTarget(BasicInput):
    
    def __init__(self, name, value, deps, function, options):
        
        messages = {'question' : '', 'old' : ''}
        BasicInput.__init__(self, name, value, messages)
        self._func = function
        for i in deps:
            i._check_depency(self)
        self._deps = deps
    
    def _real_ask(self, reconfigure):
        
        return self._func(self, *self._deps)
    
    def _check_depency(self, in_obj):
        
        if in_obj in self._deps:
            raise CyclingDepencyError()
    
    def _add_depency(self, deps):
        
        for i in deps:
            i._check_depency(self)
            self._deps.append(i)
    
    def _exec_deps(self, reconfigure):
        
        for i in self._deps:
            i._ask(reconfigure)
    
    def _eval(self, module, reconfigure):
        
        self._exec_deps(reconfigure)
        if self._dict['name'] is None:
            return self._real_ask(reconfigure)
        else:
            BasicInput._eval(self, module, True)


class SimpleTextConfig(object):
    
    def __init__(self, module, cache):
        self._mod = module
        self._ccfg = cache
        self._objs = Queue.Queue()
    
    def _input(self, name, options, class_type):
        
        value = self._mod.get_cfg(name)
        obj = class_type(name, value, options)
        self._objs.put(obj)
        return obj

    def expr(self, name, **options):
        return self._input(name, options, UserExprInput)
    
    def define(self, name, **options):
        return self._input(name, options, UserDefInput)
    
    def string(self, name, **options):
        return self._input(name, options, UserStringInput)
    
    def choose(self, name, darray, **options):
        
        value = self._mod.get_cfg(name)
        obj = UserListInput(name, value, darray, options)
        self._objs.put(obj)
        return obj
    
    def bind(self, name, function, *depencies, **options):
        "bind function + depencies to target 'name'"
        
        value = self._mod.get_cfg(name)
        obj = SimpleCallTarget(name, value, depencies, function, options)
        self._objs.put(obj)
        return obj
    
    def sub_write(self, modname, name, value):
        
        self._mod.submit_order(modname, name, value)
    
    def inread(self, name):
        
        if self._ccfg.has_key(name):
            return self._ccfg[name]
        else:
            raise MissingEntryError()
    
    def _eval(self, reconfigure=False):
        
        try:
            while True:
                obj = self._objs.get(block=False)
                try:
                    obj._eval(self._mod, reconfigure)
                except SkipException:
                    print 'skip'
                    self._objs.put(obj)
                except ValueCheckException:
                    print 'value error'
                    self._objs.put(obj)
        except Queue.Empty:
            pass
PK     N�<��       bs.py#! /usr/bin/env python
# -*- coding: utf-8 -*-
# my build system
import sys
import os
import optparse

DEBUG_ = True

import bsconfig
import bsdef
import bseval


def main():
    
    args = sys.argv[1:]
    
    if len(args) >= 1:
        basedir = os.path.split(sys.argv[0])[0]
        
        if args[0] == 'cfg':
            return bsconfig.main(args)
        elif args[0] == 'def':
            return bsdef.main(args)
        elif args[0] == 'eval':
            return bseval.main(args)
    
    #else:
    
    parser = optparse.OptionParser(
        usage="usage: %prog sub-command [options]",
        epilog="sub-command must be either 'cfg', 'def' or 'eval'")
    
    parser.add_option("-V", "--version", action="store_true",
        dest="version", help="shows version number only...")
    
    parser.set_defaults(version=False)
    
    options, args_dont_use = parser.parse_args(args)
    
    if options.version:
        print "noname-build-system version %s" % bssettings.VERSION
        return


if __name__ == '__main__':
    main()
PK     �U�<�+�Z�  �  	   bsfile.pyimport cPickle

INPUT = 'inp'
OUTPUT = 'out'


def load_cfg(file_path):
    
    f = open(file_path, 'r')
    try:
        pick = cPickle.Unpickler(f)
        config = pick.load()
        return config
    finally:
        f.close()


def save_cfg(file_path, out_vars):
    
    f = open(file_path, 'w')
    try:
        pick = cPickle.Pickler(f)
        pick.dump(out_vars)
    finally:
        f.close()
PK     MN�<U�}q  q     bssettings.pyimport re

START_TAG = "<?"
END_TAG = "?>"
CODE_RE = re.compile("^<\\?\\s*py:")
VERSION = "0.0.2"

CFG_SCRIPTFILE_RE = re.compile("^configure_([^\\s]+)[.]{1}py$")
CFG_SCRIPTFILE = "configure_%s.py"
CFG_EXTENSION_RE = re.compile("^\\s*#\\$\\s+" + 
    "([^\\n,^\\r]+)\\r{0,1}\\n{0,1}\\r{0,1}$")
CFG_USERFILE = "userconfig.pickle0"
CFG_CACHEFILE = "cachedconfig.pickle0"
PK     �V�<���	  	     bsconfig.pyimport sys
import os
import re
import shlex
import copy
import logging
import optparse

import bsmodule
import bscuser
import bssettings

LOGGER_NAME = 'config'

import __main__
if 'DEBUG_' in dir(__main__):
    __main__.LOG_LEVEL_ = logging.DEBUG
else:
    DEBUG_ = False

if 'LOG_LEVEL_' in dir(__main__):
    log = logging.getLogger(LOGGER_NAME)
    log.setLevel(__main__.LOG_LEVEL_)
    if len(log.handlers) <= 0:
        st_log = logging.StreamHandler(sys.stderr)
        st_log.setFormatter(
            logging.Formatter("%(name)s : %(threadName)s : %(levelname)s : %(message)s"))
        log.addHandler(st_log)
        del st_log
    del log
else:
    log = logging.getLogger(LOGGER_NAME)
    log.setLevel(logging.CRITICAL)


class ConfigException(Exception):
    pass


class NoDirectoryToConfigError(ConfigException):
    pass


class ModuleNameAlreadyUsedError(ConfigException):
    pass


class OnlyOneModuleInDirectoryError(ConfigException):
    pass


class ConfigManager(object):
    
    def __init__(self, dirs, verbose=False):
        
        self._dirs = dirs
        self._log = logging.getLogger(LOGGER_NAME)
        self._mods = {}
        
        if verbose:
            self._log.setLevel(logging.DEBUG)
        
        if len(self._dirs) <= 0:
            self._log.warning("no directories given!")
            raise NoDirectoryToConfigError()
    
    def _add_module(self, name, path):
        
        path = os.path.realpath(path)
        unique_name = name.upper()
        
        if unique_name in self._mods:
            if self._mods[unique_name].get_path() != path:
                self._log.critical("i have already found a module" + 
                    " with name '%s'" % unique_name)
                raise ModuleNameAlreadyUsedError()
            else:
                self._log.info("already listed this module: %s"
                     % unique_name)
        else:
            self._mods[unique_name] = bsmodule.ModuleNode(name, path)
            self._log.debug("added module %s (%s)" % (unique_name, path))
    
    def _load_modules_in_directory(self, directory):
        
        found = False
        
        if os.path.isdir(directory):
            for i in os.listdir(directory):
                fullpath = os.path.join(directory, i)
                is_a_dir = os.path.isdir(fullpath)
                sf_match = bssettings.CFG_SCRIPTFILE_RE.match(i)
                
                if (not (sf_match is None)) and (not is_a_dir):
                    if found:
                        self._log.critical("only one configure-script" + 
                            " per directory is allowed (%s)" % directory)
                        raise OnlyOneModuleInDirectoryError()
                    else:
                        self._add_module(sf_match.group(1), directory)
                        found = True
                elif is_a_dir:
                    self._load_modules_in_directory(fullpath)
    
    def find_modules(self):
        
        for i in self._dirs:
            self._load_modules_in_directory(os.path.realpath(i))
    
    def _parse_extcmd(self, cmd_line, module):
        
        args = shlex.split(cmd_line)
        
        if len(args) > 0:
            if args[0] in ('input', 'in'):
                for i in args[1:]:
                    uname = i.upper()
                    if self._mods.has_key(uname):
                        self._log.debug("add module %s" % i)
                        module.add_input(self._mods[uname])
                    else:
                        self._log.warning("couldn't find module %s" % i)
            elif args[0] in ('output', 'out'):
                for i in args[1:]:
                    uname = i.upper()
                    if self._mods.has_key(uname):
                        self._log.debug("add output module %s" % i)
                        module.add_output(self._mods[uname])
                        self._mods[uname].add_cmaster(module)
                    else:
                        self._log.warning("couldn't find module %s" % i)
    
    def load_module_extensions(self):
        
        for curr_mod in self._mods.values():
            
            self._log.debug("try load module extension (module %s)"
                % curr_mod.get_name())
            script_path = curr_mod.get_script_path()
            f = open(script_path, 'r')
            try:
                for line in f:
                    ext_match = bssettings.CFG_EXTENSION_RE.match(line)
                    if not (ext_match is None):
                        cmd = ext_match.group(1)
                        self._log.debug("extension command: '%s'" % cmd)
                        self._parse_extcmd(cmd, curr_mod)
            finally:
                f.close()
    
    def exec_modules(self, reconfig_modules={}, reconfig_all=False):
        
        mods = self._mods.values()
        if reconfig_all:
            reconfig = [i.get_name() for i in mods]
        else:
            reconfig = [i.upper() for i in reconfig_modules]
        
        while True:
            try:
                curr_mod = mods.pop()
            except IndexError:
                return
            
            # still need the reconfigure thing..
            
            curr_mod.eval_config(bscuser.SimpleTextConfig, mods, reconfig)
    
    def show_modules(self):
        
        for (k,v) in self._mods.iteritems():
            print k
            l = v.infolist()
            print "  name:", l['name']
            print "  script:", l['scriptfile']
            print "  inputs:", l['in']
            print "  outputs:", l['out']


def main(args):
    
    parser = optparse.OptionParser(
        usage="usage: %prog cfg [options] basedir [other-directories]")
    
    parser.add_option("-r", "--reconfigure", action="store_true",
        help="deletes old userconfig and reconfigures source code")
    
    parser.add_option("-c", "--change", action="append",
        help="changes given modules")
    
    parser.add_option("-v", "--verbose", action="store_true",
        help="turns on warnings (to stderr)...")
    
    parser.add_option("-s", "--show", action="store_true",
        help="shows modules")
    
    parser.set_defaults(verbose=False, reconfigure=False, change=[],
        show=False)
    
    options, args = parser.parse_args(args)
    
    cfg_obj = ConfigManager(args[1:], verbose=options.verbose)
    
    cfg_obj.find_modules()
    cfg_obj.load_module_extensions()
    
    if options.show:
        cfg_obj.show_modules()
    else:
        cfg_obj.exec_modules(reconfig_modules=options.change,
            reconfig_all=options.reconfigure)
PK     vY�<�̀�         bsdep.pyimport sys


PK     �V�<��A%  %     bsmodule.pyimport sys
import os
import copy
import logging
import bsfile
import bssettings

LOGGER_NAME = 'module'

import __main__
if 'DEBUG_' in dir(__main__):
    __main__.LOG_LEVEL_ = logging.DEBUG
else:
    DEBUG_ = False

if 'LOG_LEVEL_' in dir(__main__):
    log = logging.getLogger(LOGGER_NAME)
    log.setLevel(__main__.LOG_LEVEL_)
    if len(log.handlers) <= 0:
        st_log = logging.StreamHandler(sys.stderr)
        st_log.setFormatter(
            logging.Formatter("%(name)s : %(threadName)s : %(levelname)s : %(message)s"))
        log.addHandler(st_log)
        del st_log
    del log
else:
    log = logging.getLogger(LOGGER_NAME)
    log.setLevel(logging.CRITICAL)


class ModuleException(Exception):
    pass


class InOutNotAllowedError(ModuleException):
    pass


class CyclingOutputError(ModuleException):
    pass


class DepencyError(ModuleException):
    pass


class SoftDepencyError(DepencyError):
    pass


class ConflictingOrdersError(DepencyError):
    pass


class ModuleNode(object):
    
    def __init__(self, name, path):
        self._log = logging.getLogger(LOGGER_NAME)
        self._uname = name.upper()
        self._path = path
        self._full = os.path.join(path, 
                bssettings.CFG_SCRIPTFILE % name)
        self._in = []
        self._out = []
        self._master = []
        self._usr_config = {}
        self._orders = {}
        self._execuded = False
    
    def get_name(self):
        return self._uname
    
    def get_path(self):
        return self._path
    
    def get_script_path(self):
        return self._full
    
    def is_execuded(self):
        return self._execuded
    
    def add_input(self, module):
        
        if module in self._out:
            self._log.critical("module %s is already input for module %s"
                % (module.get_name(), self._uname))
            raise InOutNotAllowedError()
        elif module in self._in:
            self._log.debug("%s: already added module %s as input"
                % (self._uname, module.get_name()))
        else:
            self._in.append(module)
    
    def add_output(self, module):
        
        if module in self._in:
            self._log.critical("module %s is already output for module %s"
                % (module.get_name(), self._name))
            raise InOutNotAllowedError()
        elif module in self._out:
            self._log.debug("%s: already added module %s as output"
                % (self._uname, module.get_name()))
        else:
            self._out.append(module)
    
    def add_cmaster(self, module):
        
        if module in self._out:
            self._log.critical("%s can't configure it's master %s"
                % (self._uname, module.get_name()))
            raise CyclingOutputError()
        elif module in self._master:
            self._log.debug("%s: already added module %s as master"
                % (self._uname, module.get_name()))
        else:
            self._master.append(module)
    
    def check_depencies(self, usr_class, mods_to_exec, reconfig):
        
        for i in self._in:
            if i in mods_to_exec:
                mods_to_exec.remove(i)
                i.eval_config(usr_class, mods_to_exec, reconfig)
        
        for i in self._master:
            if i in mods_to_exec:
                mods_to_exec.remove(i)
                i.eval_config(usr_class, mods_to_exec, reconfig)
        
        self._log.debug("now checking depencies for module %s"
            % self._uname)
        
        for i in self._in:
            if not i.is_execuded():
                self._log.critical("dep. error in module %s (input %s)"
                    % (self._uname, i.get_name()))
                raise DepencyError()
        
        for i in self._master:
            if not i.is_execuded():
                self._log.warning("%s: master %s not execuded"
                    % (self._uname, i.get_name()))
                raise SoftDepencyError()
        
        self._log.debug("depency checked for module %s" % self._uname)
    
    def get_usr_cfg(self):
        return copy.deepcopy(self._usr_config)
    
    def get_cfg(self, name):
        
        cfg_name = "%s_%s" % (self._uname, name)
        
        if cfg_name in self._usr_config:
            return self._usr_config[cfg_name]
        else:
            return None
    
    def add_cfg(self, name, value, overwrite=False):
        
        cfg_name = "%s_%s" % (self._uname, name)
        print "add cfg %s = %s" % (name, value)
        
        if (not (cfg_name in self._usr_config)) or overwrite:
            self._usr_config[cfg_name] = value
            # that's often...
            self._save_usr_config()
            return True
        else:
            return False
    
    def submit_order(self, modname, name, value):
        
        modname = modname.upper()
        for i in self._out:
            if modname == i.get_name():
                i._add_order(self, name, value, True)
                return True
        
        return False
    
    def _exec_orders(self):
        
        for (name, order) in self._orders.iteritems():
            self.add_cfg(name, order[0], overwrite=True)
    
    def _add_order(self, module, name, value, overwrite):
        
        if self._orders.has_key(name):
            order = self._orders[name]
            if order[1] == module:
                if overwrite:
                    self._orders[name] = [value, module]
                    return True
                else:
                    return False
            else:
                self._log.critical("can't overwrite %s" % name)
                raise ConflictingOrdersError()
        else:
            self._orders[name] = [value, module]
    
    def _load_config(self):
        
        usr_file = os.path.join(self._path, bssettings.CFG_USERFILE)
        cache_file = os.path.join(self._path, bssettings.CFG_CACHEFILE)
        ccfg = {}
        
        if os.path.exists(usr_file):
            self._usr_config = bsfile.load_cfg(usr_file)
        
        for i in self._in:
            cfg = i.get_usr_cfg()
            ccfg.update(cfg)
        
        return ccfg
    
    def _save_config(self, cache):
        
        cache_file = os.path.join(self._path, bssettings.CFG_CACHEFILE)
        self._save_usr_config()
        bsfile.save_cfg(cache_file, cache)
    
    def _save_usr_config(self):
        usr_file = os.path.join(self._path, bssettings.CFG_USERFILE)
        bsfile.save_cfg(usr_file, self._usr_config)
    
    def eval_config(self, usr_class, mods_to_exec, reconfig):
        
        reconfigure = (self._uname in reconfig)
        self.check_depencies(usr_class, mods_to_exec, reconfig)
        ccfg = self._load_config()
        self._exec_orders()
        usercfg = usr_class(self, ccfg)
        
        env = {'__builtins__' : __builtins__,
            'BS_VERSION' : bssettings.VERSION,
            'cfg' : usercfg}
        
        execfile(self._full, env, env)
        
        exec("cfg._eval(%s)" % str(reconfigure), env, env)
        
        #env['cfg']._eval(reconfigure)
        
        self._save_config(ccfg)
        self._execuded = True
    
    def infolist(self):
        
        return {'name' : copy.copy(self._uname),
                'scriptfile' : copy.copy(self._full),
                'in' : [i.get_name() for i in self._in],
                'out' : [i.get_name() for i in self._out]}

PK     Ar�<Kڽ�X  X     npyck.py#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import stat
import zipfile
import tempfile
import optparse
import fnmatch

VERSION = "0.1.1"


class NpyckUtil(object):
    
    def __init__(self, zip_path):
        
        self.path = zip_path
        self.version = VERSION
    
    def ne_read(self, filename):
        """No exception read...
        
        Returns None on any error (except if there is an error while
        opening the zip archive, which would be a real bad error),
        on success it returns the opened file's content.
        """
        value = None
        zip = zipfile.ZipFile(self.path, 'r')
        try:
            value = zip.read(filename)
        except (KeyboardInterrupt, SystemExit), ex:
            raise ex
        except:
            return None
        finally:
            zip.close()
        
        return value
    
    def read(self, filename):
        """Normal read...
        
        Returns content of given file, if the file doesn't exist
        there will be an exception.
        """
        value = None
        zip = zipfile.ZipFile(self.path, 'r')
        try:
            value = zip.read(filename)
        finally:
            zip.close()
        
        return value


def load_pack(main_file, path, use_globals=True):
    
    import runpy
    
    if use_globals:
        environment = {'NPYCK_' : NpyckUtil(path)}
    else:
        environment = {}
    
    loader = runpy.get_loader(main_file)
    if loader is None:
        raise ImportError("No module named " + main_file)
    code = loader.get_code(main_file)
    if code is None:
        raise ImportError("No code object available for " + main_file)
    
    if sys.version_info[0] == 2:
        if sys.version_info[1] == 5:
            return runpy._run_module_code(code, environment, '__main__',
                            path, loader, True)
        elif sys.version_info[1] == 6:
            return runpy._run_module_code(code, environment, '__main__',
                            path, loader, '__main__')
    
    print "unsupported interpreter version..."
    
    

def read_pydir(dirname):
    
    return fnmatch.filter(os.listdir(dirname), '*.py')


def pack(main_file, src_files, dstream=sys.stdout, use_globals=True):
    
    os_handle, zip_path = tempfile.mkstemp()
    os.close(os_handle)
    
    zf = zipfile.ZipFile(zip_path, 'w')
    
    for pyfile in src_files:
        arc = os.path.split(pyfile)
        zf.write(pyfile, arc[1])
    
    zf.write(sys.argv[0], "npyck.py")
    zf.close()
    
    zf = open(zip_path, 'r')
    data = zf.read()
    zf.close()
    
    os.remove(zip_path)
    
    dstream.write('#!/bin/sh\n')
    dstream.write('python -c"import sys;')
    dstream.write("sys.argv[0] = '$0';")
    dstream.write("sys.path.insert(0, '$0');")
    dstream.write("import npyck;")
    
    if use_globals:
        dstream.write("npyck.load_pack('%s', '$0', use_globals=True)"
         % os.path.splitext(os.path.basename(main_file))[0])
    else:
        dstream.write("npyck.load_pack('%s', '$0', use_globals=False)"
         % os.path.splitext(os.path.basename(main_file))[0])
    
    dstream.write('" $*\n')
    dstream.write("exit\n\n")
    dstream.write(data)
    
    dstream.close()


def main():
    
    parser = optparse.OptionParser(
        usage = "usage: %prog [options] main-file [other source files]"
    )
    
    parser.add_option("-o", "--output", dest="filename",
        help="write output to file")
    
    parser.add_option("-a", "--all", action="store_true",
        dest="all", help="add all source files in directory")
    
    parser.add_option("-n", "--no_globals", action="store_false",
        dest="use_globals", help="doesn't include " +
        "globals from loader, which means NPYCK_ will NOT be set")
    
    parser.add_option("-V", "--version", action="store_true",
        dest="version", help="shows version number only...")
    
    parser.set_defaults(all=False, use_globals=True, version=False)
    
    options, args = parser.parse_args()
    
    if options.version:
        print("npyck version %s" % VERSION)
        return
    
    if len(args) < 1:
        parser.print_help(file=sys.stderr)
        return
    else:
        mainfile = args[0]
    
    args = frozenset(args)
    
    if options.all:
        args = args.union(read_pydir("."))
    
    if options.filename:
        f = open(options.filename, 'w')
        os.chmod(options.filename, 0764)
        
        pack(mainfile, args, dstream=f, 
            use_globals=options.use_globals)
    else:
        pack(mainfile, args, use_globals=options.use_globals)


if __name__ == '__main__':
    main()
PK     �U�<id�y�	  �	             ��    bsdef.pyPK     ��<�l�g  g  	           ��
  bseval.pyPK     �]�<P�Ծ'  '  
           ���  bscuser.pyPK     N�<��               큾D  bs.pyPK     �U�<�+�Z�  �  	           ���H  bsfile.pyPK     MN�<U�}q  q             ���J  bssettings.pyPK     �V�<���	  	             ��VL  bsconfig.pyPK     vY�<�̀�                 ���f  bsdep.pyPK     �V�<��A%  %             ���f  bsmodule.pyPK     Ar�<Kڽ�X  X             �	�  npyck.pyPK    
 
 (  ��    