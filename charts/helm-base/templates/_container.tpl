{{- define "helm-base.containerBase" -}}
{{- $name := include "helm-base.fullname" $ -}}

{{- $tag := "" }}
{{- if not $.image }}
{{- $tag = printf ":%s" (coalesce $.Values.image.tag $.Values.global.image.tag) }}
{{- end }}


- name: {{ tpl $.name $ }}
  image: "{{ tpl (tpl (coalesce $.image $.Values.image.repository $.Values.global.image.repository) $) $ }}{{ $tag }}"
  imagePullPolicy: {{ coalesce $.imagePullPolicy $.Values.global.imagePullPolicy "Always" }}
{{- if $.command }}  
  command: 
{{- $new := list }}
{{- range $_, $v := $.command }}
{{- with $v }}
{{- $new = append $new (tpl (tpl . $) $) }}
{{- end }}
{{- end }}
{{ toYaml $new | indent 2 }}
{{- end }}
{{- if $.args }}  
  args: 
{{- range $_, $v := $.args }}
{{- with $v }}
  - "{{ tpl . $ -}}"
{{- end }}
{{- end }}
{{- end }}

{{- if $.tty }}
  tty: true
{{- end }}

{{- if $.stdin }}
  stdin: true 
{{- end }}


{{- if $.workingDir }}
  workingDir: {{ tpl $.workingDir $ }}
{{- end }}
{{- if and $.resources (or $.resources.requests $.resources.limits) }}
  resources:
{{ tpl (toYaml $.resources) $ | indent 4 }}
{{- end -}} {{/* End resources */}}

{{- include "helm-base.volumeMounts" $ | indent 2 }}

{{- if $.privileged }}
  securityContext:
    privileged: true
{{- else if $.securityContext }}
  securityContext:
{{ toYaml $.securityContext | nindent 4 }}
{{- else }}
{{ include "helm-base.containerSecurityContext" $ | indent 2 }}
{{- end -}} {{/* End privileged */}}

{{- if or $.env $.Values.env $.Values.global.env $.envFrom $.Values.envFrom $.envRaw $.Values.envRaw $.Values.global.envRaw }}
  {{- $envFromYaml := include "helm-base.envFromList" $ }}
  {{- if $envFromYaml }}
  envFrom:
{{ $envFromYaml | indent 2 }}
  {{- end }}

  env:
  {{- $hasListEnv := false }}
  {{- if or (and $.env (eq (kindOf $.env) "slice")) (and $.Values.env (eq (kindOf $.Values.env) "slice")) (and $.Values.global.env (eq (kindOf $.Values.global.env) "slice")) }}
    {{- $hasListEnv = true }}
    {{- $envList := list }}
    {{- if and $.Values.global.env (eq (kindOf $.Values.global.env) "slice") }}
      {{- $envList = concat $envList $.Values.global.env }}
    {{- end }}
    {{- if and $.Values.env (eq (kindOf $.Values.env) "slice") }}
      {{- $envList = concat $envList $.Values.env }}
    {{- end }}
    {{- if and $.env (eq (kindOf $.env) "slice") }}
      {{- $envList = concat $envList $.env }}
    {{- end }}
    {{- if $envList }}
{{ toYaml $envList | indent 2 }}
    {{- end }}
  {{- end }}
  {{- if not $hasListEnv }}
  {{- $envMapYaml := include "helm-base.envVars" $ }}
  {{- if $envMapYaml }}
  {{- $envMap := fromYaml $envMapYaml }}
  {{- range $dk, $dv := $envMap }}
  - name: {{ $dk }}
    value: "{{ with $dv }}{{ tpl (. | toString) $ }}{{end}}"
  {{- end }}
  {{- end }}
  {{- end }}

  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_IP
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: status.podIP

  {{- $rawYaml := include "helm-base.envRawList" $ }}
  {{- if $rawYaml }}
{{ $rawYaml | indent 2 }}
  {{- end }}
{{- end }} {{/* End env */}}

{{- if $.waitFor -}}
{{- if $.waitFor.port }}
  livenessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
  readinessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
{{- else }}
{{- if $.waitFor.command }}
  livenessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
  readinessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
{{- end }} {{/* End .command */}}
{{- end }} {{/* End .waitFor.port */}}
{{- end }} {{/* End .waitFor */}}

{{- if $.readinessProbe }}
  readinessProbe:
{{ toYaml $.readinessProbe | indent 4 }}
{{- end }}

{{- if $.livenessProbe }}
  livenessProbe:
{{ toYaml $.livenessProbe | indent 4 }}
{{- end }}

{{- if $.startupProbe }}
  startupProbe:
{{ toYaml $.startupProbe | indent 4 }}
{{- end }}

{{- if $.ports }}
  ports:
{{- if eq (kindOf $.ports) "slice" }}
{{- range $_, $port := $.ports }}
  - name: {{ default (printf "p-%d" (default $port.port $port.containerPort)) $port.name }}
    containerPort: {{ default $port.port $port.containerPort }}
    {{- if $port.protocol }}
    protocol: {{ $port.protocol }}
    {{- else }}
    protocol: TCP
    {{- end }}
    {{- if $port.hostPort }}
    hostPort: {{ $port.hostPort }}
    {{- end }}
{{- end }}
{{- else }}
{{- range $k, $v := $.ports }}
{{- if eq (kindOf $v) "map" }}
  - name: {{ default ($k | toString) $v.name }}
    containerPort: {{ default $v.port $v.containerPort }}
    protocol: {{ default "TCP" $v.protocol }}
    {{- if $v.hostPort }}
    hostPort: {{ $v.hostPort }}
    {{- end }}
{{- else }}
  - name: {{ printf "p-%s" ($k | toString) }}
    containerPort: {{ $v }}
    protocol: "TCP"
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- if $.lifecycle }}
  lifecycle:
{{ toYaml $.lifecycle | indent 4 }}
{{- end }}

{{- end }}