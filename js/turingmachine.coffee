if !tm? then window.tm = tm = {}

programs = {}


progTupleArr = (ar) ->
  progTuple(ar[0], ar[1], ar[2], ar[3], ar[4])

progTuple = (q0, s0, q1, s1, d) ->
  r = {q0: q0, s0: (if s0 == "_" then null else s0[0]), q1: q1, s1: (if s1 == "_" then null else s1[0]), d: parseInt(d)}
  r

procStep = (q1, s1, d, rule, expand) ->
  {q1: q1, s1: s1, d: d, rule: rule, expand: expand}

strToProgram = (str, nameToSave) ->
  commands = str.split(",").map((s) -> s.trim().split(/\s+/))
  tuples = []
  result = {tuples: tuples}
  for command in commands
    if command.length == 2 and command[0].toUpperCase() == "ACCEPT"
      result.acceptState = command[1]
    if command.length == 2 and command[0].toUpperCase() == "REJECT"
      result.rejectState = command[1]
    else if command.length == 2 and command[0].toUpperCase() == "INITIAL"
      result.initState = command[1]
    else if command.length == 4  and command[2].toUpperCase() == "EXEC"
      s0 = command[1];
      tuples.push({q0: command[0], s0: (if s0 == "_" then null else s0[0]), exec: command[3]})
    else if command.length == 5
      tuples.push(progTupleArr(command))

  if typeof nameToSave == "string" and !nameToSave.match(/^\s*$/g)
    programs[nameToSave] = result

  result


strToInput = (str) ->
  str.split('').map((s) -> if s == "_" then null else s)


calc = (program, input, maxSteps=10000, pos=0) ->
  state = program.initState
  acceptState = program.acceptState
  rejectState = program.rejectState
  steps = []
  while state != acceptState and state != rejectState
    if steps.length > maxSteps
      return {steps: steps, output: input, finalState: state, finalPos: pos, outOfSteps: true}
    step = null
    execResult = null
    sym = input[pos]
    for tuple in program.tuples
      if sym == tuple.s0 and state == tuple.q0
        if tuple.exec?
          if programs[tuple.exec]?
            execResult = calc(programs[tuple.exec], input, maxSteps-steps.length, pos)
            steps.push({rule: tuple, exec: tuple.exec})
            steps.push execResult.steps...
            if !execResult.error? and !execResult.outOfSteps
              steps.push({rule: tuple, execEnd: tuple.exec})
            pos = execResult.finalPos
            state = execResult.finalState
          else
            console.log "not found "+tuple.exec
        else
          state = tuple.q1
          input[pos] = tuple.s1
          pos += tuple.d
          expand = 0
          if pos == -1
            input.unshift(null)
            pos = 0
            expand = -1
          else if typeof input[pos] == "undefined"
            input[pos] = null
            expand = 1
          step = procStep(state, tuple.s1, tuple.d, tuple, expand)
        break
    if step?
      steps.push(step)
    else if execResult != null
      if execResult.error?
        console.log(execResult.error)
        console.log(program)
        console.log(input)
        console.log(state+" "+pos)
        error = {message: execResult.error.message, state: state, input: sym}
        break
      if execResult.outOfSteps
        return {steps: steps, output: input, finalState: state, finalPos: pos, outOfSteps: true}
    else
      console.log(program)
      console.log(input)
      console.log(state+" "+pos)
      error = {message: "Illegal State/Input.", state: state, input: sym}
      break
  {steps: steps, output: input, finalState: state, finalPos: pos, error: error, accept: state == acceptState, reject: state == rejectState}

_normalizeHeadPos = (headPos, target) ->
  tape = target.children(".tape")
  firstCellWrap = tape.children(":first")
  cellWidth =  firstCellWrap.width()
  firstCellMargin = parseInt(firstCellWrap.css("margin-left").replace("px", ""))
  if headPos < 4*cellWidth
    {headPos: 4*cellWidth, firstCellMargin: firstCellMargin+(4*cellWidth-headPos)}
  else if headPos > tape.width()-4*cellWidth
    {headPos: tape.width()-4*cellWidth, firstCellMargin: firstCellMargin-(headPos - (tape.width()-4*cellWidth))}
  else
    {headPos: headPos, firstCellMargin: firstCellMargin}


_cellPos = (pos, target) ->
  jQuery(target.find(".tapeCellWrap")[pos]).position().left

_cellAt = (pos, target) ->
  jQuery(target.find(".tapeCell")[pos])

_setSymbol = (cell, sym) ->
  if sym == null
    cell.html("&nbsp;")
  else
    cell.text(sym)

_createCell = (symbol) ->
  cell = jQuery(document.createElement("span"))
  cell.addClass("tapeCell")
  _setSymbol(cell, symbol)
  cellWrap = jQuery(document.createElement("span"))
  cellWrap.addClass("tapeCellWrap").append(cell)
  cellWrap

_bubblePos = (headPos, head, bubble, target) ->
  headPos + head.width() - (bubble.width())/2

draw = (tape, pos, state, target) ->
  target = jQuery(target)
  offset = target.data("offset")
  tapeView = target.children(".tape")
  tapeView.find(".tapeCell").html("&nbsp;")
  for sym, symPos in tape
    if offset+symPos+3 > tapeView.children().length
      tapeView.append(_createCell(null))
      tapeView.append(_createCell(null))
      tapeView.append(_createCell(null))
    _setSymbol(_cellAt(symPos+offset, target), sym)
  head = target.children(".machineHead")
  head.text(state)
  headPos = _cellPos(pos+offset, target)
  normalize = _normalizeHeadPos(headPos, target)
  headPos = normalize.headPos
  tapeView.children(":first").css("margin-left", normalize.firstCellMargin+"px")
  head.css("left", headPos)
  bubble = target.children(".bubble")
  bubble.css("bottom", 0)
  bubble.css("left", _bubblePos(headPos, head, bubble, target))
  bubble.text("hello,\nhuman!")
  target.data("pos", pos)


updateDraw = (step, target, nextAction) ->
  target = jQuery(target)
  if step.exec?
    li = jQuery("<li></li>");
    li.text(step.exec)
    jQuery("#stack ul").prepend(li)
    if nextAction then nextAction()
  else if step.execEnd?
    jQuery("#stack ul").children("li:first").remove()
    if nextAction then nextAction()
  else
    head = target.children(".machineHead")
    tape = target.children(".tape")
    bubble = target.children(".bubble")
    offset = target.data("offset")
    firstCellWrap = tape.children(":first")
    cellWidth =  firstCellWrap.width()
    firstCellMargin = parseInt(firstCellWrap.css("margin-left").replace("px", ""))
    head.text(step.q1)
    r = step.rule
    bubble.text(r.q0+" "+(if r.s0 == null then "_" else r.s0)+"\n"+r.q1+" "+(if r.s1 == null then "_" else r.s1)+" "+r.d)
    pos = target.data("pos")
    _setSymbol(_cellAt(pos+offset, target), step.s1)
    pos += step.d
    if step.expand == -1
      offset -= 1
      pos = 0
    if offset < 5
      refer = _cellAt(pos+offset, target).parent()
      before = refer.position().left
      toAdd = 8-offset
      for i in [1..toAdd]
        console.log(i+"/"+toAdd)
        firstCellWrap.after(_createCell(null))
      after = refer.position().left
      # firstCellWrap.css("margin-left", (firstCellMargin-(toAdd*cellWidth))+"px")
      firstCellWrap.css("margin-left", (firstCellMargin-(after-before))+"px")
      offset += toAdd
    else if offset+pos+4 > tape.children().length
      tape.append(_createCell(null))
      tape.append(_createCell(null))
      tape.append(_createCell(null))
      tape.append(_createCell(null))
    target.data("pos", pos)
    target.data("offset", offset)
    interval = MAX_INTEVAL - jQuery('#speed').slider( "value" )
    headPos = _cellPos(pos+offset, target)
    normalize = _normalizeHeadPos(headPos, target)
    headPos = normalize.headPos
    if normalize.firstCellMargin != firstCellMargin
      firstCellWrap.animate({ "margin-left": normalize.firstCellMargin+"px" }, interval, "swing")

    head.animate({ "left": headPos+"px" }, interval, "swing", nextAction)
    bubble.animate({ "left": _bubblePos(headPos, head, bubble, target)+"px" }, interval, "swing")

tm.programs = programs
tm.strToProgram = strToProgram
tm.strToInput = strToInput
tm.calc = calc
tm.draw = draw
tm.updateDraw = updateDraw
